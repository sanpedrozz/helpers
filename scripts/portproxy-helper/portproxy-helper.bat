@echo off
setlocal EnableExtensions EnableDelayedExpansion
title PortProxy Helper (v4tov4)

:: -----------------------------------------------------------------
:: PortProxy Helper
:: A tiny utility to manage v4-to-v4 port proxy rules via ``netsh``.
:: The script re-launches itself with administrative rights when
:: required.  Adjust ``DEFAULT_DEST_IP`` below to match your network.
:: -----------------------------------------------------------------

:: Default destination IP used when adding new rules
set "DEFAULT_DEST_IP=192.168.10.5"

:: Ensure we are running with administrative privileges
call :EnsureAdmin


:Menu
cls
echo ===============================================
echo           PortProxy Helper (v4tov4)
echo ===============================================
echo [1] Add / Update a rule
echo [2] Disconnect all clients (restart iphlpsvc)
echo [3] Remove one rule
echo [4] Remove ALL rules
echo [5] Show rules
echo [6] Show active connections on a port
echo [7] Exit
echo ===============================================
echo ***********************************************
echo *  HINTS:                                     *
echo *    - Modbus TCP usually uses port 502       *
echo *    - OPC UA usually uses port 4840          *
echo ***********************************************
echo ===============================================
set /p CHOICE=Select option (1-7):

if "%CHOICE%"=="1" goto AddRule
if "%CHOICE%"=="2" goto RestartSvc
if "%CHOICE%"=="3" goto RemoveRule
if "%CHOICE%"=="4" goto RemoveAll
if "%CHOICE%"=="5" goto ShowRules
if "%CHOICE%"=="6" goto ShowConnections
if "%CHOICE%"=="7" exit /b

goto Menu


:AddRule
cls
echo ==============================
echo     ADD / UPDATE A RULE
echo ==============================
echo [1] Modbus TCP (port 502)
echo [2] OPC UA     (port 4840)
echo [3] Custom port
echo ==============================
set /p PORTCHOICE=Choose option (1-3): 

if "%PORTCHOICE%"=="1" (
    set "PORT=502"
) else if "%PORTCHOICE%"=="2" (
    set "PORT=4840"
) else if "%PORTCHOICE%"=="3" (
    call :ASK_PORT PORT "Enter custom port (1..65535)"
) else (
    echo [!] Invalid choice.
    pause
    goto Menu
)

:: LISTEN_IP fixed; LISTEN_PORT = DEST_PORT
set "LISTEN_IP=0.0.0.0"
set "LISTEN_PORT=%PORT%"
set "DEST_PORT=%PORT%"

:: ask only for destination IP
set /p DEST_IP=Enter destination IP (remote) [default %DEFAULT_DEST_IP%]:
if "%DEST_IP%"=="" set "DEST_IP=%DEFAULT_DEST_IP%"
call :CHECK_IP "%DEST_IP%"
if errorlevel 1 (
    echo [!] Invalid IPv4 format. Example: 192.168.10.5
    pause
    goto Menu
)

echo.
echo Removing old rule if exists...
netsh interface portproxy delete v4tov4 listenport=%LISTEN_PORT% listenaddress=%LISTEN_IP% >nul 2>&1
netsh interface portproxy delete v6tov4 listenport=%LISTEN_PORT% listenaddress=:: >nul 2>&1

echo Adding new rule:
echo     %LISTEN_IP%:%LISTEN_PORT%  -->  %DEST_IP%:%DEST_PORT%
netsh interface portproxy add v4tov4 listenport=%LISTEN_PORT% listenaddress=%LISTEN_IP% connectport=%DEST_PORT% connectaddress=%DEST_IP%
netsh interface portproxy add v6tov4 listenport=%LISTEN_PORT% listenaddress=:: connectport=%DEST_PORT% connectaddress=%DEST_IP%

if errorlevel 1 (
    echo [!] Failed to create portproxy rule.
    pause
    goto Menu
)

echo.
echo [+] Rule created successfully.
echo.
echo Adding firewall rules...
netsh advfirewall firewall delete rule name="PortProxy_%PORT%_IN" >nul 2>&1
netsh advfirewall firewall delete rule name="PortProxy_%PORT%_OUT" >nul 2>&1
netsh advfirewall firewall add rule name="PortProxy_%PORT%_IN"  dir=in  action=allow protocol=TCP localport=%PORT%
netsh advfirewall firewall add rule name="PortProxy_%PORT%_OUT" dir=out action=allow protocol=TCP remoteport=%PORT%
if errorlevel 1 (
    echo [!] Failed to create firewall rules.
    pause
    goto Menu
)
echo.
echo Dump of current PortProxy configuration:
echo ---------------------------------------
netsh interface portproxy dump
echo ---------------------------------------
pause
goto Menu


:RestartSvc
cls
echo Restarting IP Helper service (iphlpsvc) to disconnect all PortProxy clients...
echo.
net stop iphlpsvc
echo.
timeout /t 2 >nul
net start iphlpsvc
echo.
echo Done. All existing PortProxy connections were dropped.
pause
goto Menu


:RemoveRule
cls
set /p RP=Enter LISTEN PORT to remove:
netsh interface portproxy delete v4tov4 listenport=%RP% listenaddress=0.0.0.0
netsh interface portproxy delete v6tov4 listenport=%RP% listenaddress=::
pause
goto Menu


:RemoveAll
cls
echo Removing ALL rules...
netsh interface portproxy reset
pause
goto Menu


:ShowRules
cls
echo Current PortProxy rules:
echo.
netsh interface portproxy show all
echo.
pause
goto Menu

:ShowConnections
cls
set /p SCPORT=Enter port to inspect:
echo.
echo Active connections on port %SCPORT%:
netstat -ano ^| findstr /R /C:":%SCPORT% "
echo.
pause
goto Menu

:: ---------- Helpers ----------
:EnsureAdmin
:: Relaunch the script as administrator if required
net session >nul 2>&1
if %errorlevel% neq 0 (
    powershell -NoProfile -ExecutionPolicy Bypass -Command ^
      "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)
goto :eof

:: ------------------------------
:ASK_PORT
:: %1 = var name, %2 = prompt
set "_var=%~1"
set "_prompt=%~2"
:ASK_PORT_LOOP
set /p "%_var%=%_prompt%: "
set "VAL=!%_var%!"
echo %VAL%| findstr /R "^[0-9][0-9]*$" >nul || (echo [!] Enter digits only.& goto :ASK_PORT_LOOP)
if %VAL% lss 1  (echo [!] Port must be >= 1.& goto :ASK_PORT_LOOP)
if %VAL% gtr 65535 (echo [!] Port must be <= 65535.& goto :ASK_PORT_LOOP)
goto :eof

:CHECK_IP
set "IP=%~1"
echo %IP%| findstr /R "^[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*$" >nul || (exit /b 1)
exit /b 0
