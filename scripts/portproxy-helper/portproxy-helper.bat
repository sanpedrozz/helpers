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
set "RECOVERY_TASK_STARTUP=PortProxy Helper - at startup"
set "RECOVERY_TASK_NETWORK=PortProxy Helper - network reconnect"
set "RECOVERY_SOURCE=%~dp0portproxy-recovery.ps1"
set "RECOVERY_DIR=%ProgramData%\PortProxyHelper"
set "RECOVERY_SCRIPT=%RECOVERY_DIR%\portproxy-recovery.ps1"
set "RECOVERY_LOG=%RECOVERY_DIR%\portproxy-recovery.log"

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
echo [7] Enable automatic recovery after reboot / network reconnect
echo [8] Disable automatic recovery
echo [9] Exit
echo [0] Show automatic recovery status and log
echo ===============================================
echo ***********************************************
echo *  HINTS:                                     *
echo *    - Modbus TCP usually uses port 502       *
echo *    - OPC UA usually uses port 4840          *
echo ***********************************************
echo ===============================================
set /p CHOICE=Select option (0-9):

if "%CHOICE%"=="1" goto AddRule
if "%CHOICE%"=="2" goto RestartSvc
if "%CHOICE%"=="3" goto RemoveRule
if "%CHOICE%"=="4" goto RemoveAll
if "%CHOICE%"=="5" goto ShowRules
if "%CHOICE%"=="6" goto ShowConnections
if "%CHOICE%"=="7" goto EnableRecovery
if "%CHOICE%"=="8" goto DisableRecovery
if "%CHOICE%"=="9" exit /b
if "%CHOICE%"=="0" goto ShowRecoveryStatus

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

:: normalize accidental spaces around the value
for /f "tokens=* delims= " %%A in ("%DEST_IP%") do set "DEST_IP=%%A"

:: validate IPv4 directly here to avoid label-call edge cases in some cmd environments
echo %DEST_IP%| findstr /R "^[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*$" >nul
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
if errorlevel 1 (
    echo [!] Failed to create the IPv4 PortProxy rule.
    pause
    goto Menu
)
netsh interface portproxy add v6tov4 listenport=%LISTEN_PORT% listenaddress=:: connectport=%DEST_PORT% connectaddress=%DEST_IP%
if errorlevel 1 (
    echo [!] Failed to create the IPv6 PortProxy rule.
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
if errorlevel 1 (
    echo [!] Failed to create the inbound firewall rule.
    pause
    goto Menu
)
netsh advfirewall firewall add rule name="PortProxy_%PORT%_OUT" dir=out action=allow protocol=TCP remoteport=%PORT%
if errorlevel 1 (
    echo [!] Failed to create the outbound firewall rule.
    pause
    goto Menu
)
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
if errorlevel 1 (
    echo [!] Failed to stop IP Helper.
    pause
    goto Menu
)
echo.
timeout /t 2 >nul
net start iphlpsvc
if errorlevel 1 (
    echo [!] Failed to start IP Helper.
    pause
    goto Menu
)
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


:EnableRecovery
cls
echo Enabling automatic PortProxy recovery...
call :InstallRecoveryTasks
if errorlevel 1 (
    echo.
    echo [!] Could not create one or more scheduled tasks.
) else (
    echo.
    echo [+] Enabled and verified. IP Helper will be restarted 30 seconds after
    echo     Windows starts and 10 seconds after a network connection is detected.
)
pause
goto Menu


:DisableRecovery
cls
echo Disabling automatic PortProxy recovery...
schtasks /delete /tn "%RECOVERY_TASK_STARTUP%" /f >nul 2>&1
schtasks /delete /tn "%RECOVERY_TASK_NETWORK%" /f >nul 2>&1
echo [+] Automatic recovery tasks were removed.
pause
goto Menu


:ShowRecoveryStatus
cls
echo Automatic recovery tasks:
echo ---------------------------------------
schtasks /query /tn "%RECOVERY_TASK_STARTUP%" /v /fo list
echo ---------------------------------------
schtasks /query /tn "%RECOVERY_TASK_NETWORK%" /v /fo list
echo ---------------------------------------
echo.
echo Recovery log (latest entries):
if exist "%RECOVERY_LOG%" (
    powershell -NoProfile -Command "Get-Content -LiteralPath '%RECOVERY_LOG%' -Tail 30"
) else (
    echo No log yet. Enable recovery with option 7, then reconnect the network.
)
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
:InstallRecoveryTasks
:: Scheduled tasks run under SYSTEM, so they also work when no user is logged on.
:: Event 10000 is written by NetworkProfile when a network becomes connected.
if not exist "%RECOVERY_SOURCE%" (
    echo [!] Missing helper file: "%RECOVERY_SOURCE%"
    exit /b 1
)
if not exist "%RECOVERY_DIR%" mkdir "%RECOVERY_DIR%" >nul 2>&1
if not exist "%RECOVERY_DIR%" (
    echo [!] Could not create "%RECOVERY_DIR%".
    exit /b 1
)
copy /y "%RECOVERY_SOURCE%" "%RECOVERY_SCRIPT%" >nul
if errorlevel 1 (
    echo [!] Could not install the recovery script.
    exit /b 1
)
wevtutil set-log "Microsoft-Windows-NetworkProfile/Operational" /enabled:true >nul 2>&1
if errorlevel 1 (
    echo [!] Could not enable the NetworkProfile event log.
    exit /b 1
)
schtasks /create /tn "%RECOVERY_TASK_STARTUP%" /sc onstart /delay 0000:30 /tr "powershell.exe -NoProfile -ExecutionPolicy Bypass -File %RECOVERY_SCRIPT% -DelaySeconds 0" /ru SYSTEM /rl HIGHEST /f
if errorlevel 1 exit /b 1
schtasks /create /tn "%RECOVERY_TASK_NETWORK%" /sc onevent /ec "Microsoft-Windows-NetworkProfile/Operational" /mo "*[System[EventID=10000]]" /tr "powershell.exe -NoProfile -ExecutionPolicy Bypass -File %RECOVERY_SCRIPT%" /ru SYSTEM /rl HIGHEST /f
if errorlevel 1 exit /b 1
schtasks /query /tn "%RECOVERY_TASK_STARTUP%" >nul 2>&1
if errorlevel 1 exit /b 1
schtasks /query /tn "%RECOVERY_TASK_NETWORK%" >nul 2>&1
if errorlevel 1 exit /b 1
exit /b 0

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
