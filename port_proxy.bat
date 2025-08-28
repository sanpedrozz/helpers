@echo off
:: =============================================================
:: PortProxy Helper (menu) - ASCII only
:: Add / Show / Remove port forwarding rules (v4tov4)
:: Requires: run as Administrator
:: =============================================================

title PortProxy Helper
setlocal ENABLEDELAYEDEXPANSION

:: Defaults (edit if needed)
set "LISTEN_IP=0.0.0.0"
set "LISTEN_PORT=4840"
set "DEST_IP=192.168.10.50"
set "DEST_PORT=4840"

:menu
cls
echo ===============================================
echo           PortProxy Helper (v4tov4)
echo ===============================================
echo [1] Add / Update a rule
echo [2] Remove one rule
echo [3] Remove ALL rules
echo [4] Show rules
echo [5] Exit
echo ===============================================
echo ***********************************************
echo *  HINTS:                                     *
echo *    - Modbus TCP usually uses port 502       *
echo *    - OPC UA usually uses port 4840          *
echo ***********************************************
echo ===============================================
set /p choice=Select option (1-5): 

if "%choice%"=="1" goto add_rule
if "%choice%"=="2" goto remove_one
if "%choice%"=="3" goto remove_all
if "%choice%"=="4" goto show_rules
if "%choice%"=="5" goto end
goto menu

:add_rule
cls
echo --- Add / Update rule ---
echo (Press Enter to keep current value)
set /p LISTEN_IP_IN=Listen IP [%LISTEN_IP%]: 
if not "%LISTEN_IP_IN%"=="" set "LISTEN_IP=%LISTEN_IP_IN%"
set /p LISTEN_PORT_IN=Listen Port [%LISTEN_PORT%]: 
if not "%LISTEN_PORT_IN%"=="" set "LISTEN_PORT=%LISTEN_PORT_IN%"
set /p DEST_IP_IN=Destination IP [%DEST_IP%]: 
if not "%DEST_IP_IN%"=="" set "DEST_IP=%DEST_IP_IN%"
set /p DEST_PORT_IN=Destination Port [%DEST_PORT%]: 
if not "%DEST_PORT_IN%"=="" set "DEST_PORT=%DEST_PORT_IN%"

echo.
echo Creating rule: %LISTEN_IP%:%LISTEN_PORT% ^> %DEST_IP%:%DEST_PORT%
echo.

netsh interface portproxy delete v4tov4 listenaddress=%LISTEN_IP% listenport=%LISTEN_PORT% >nul 2>&1
netsh interface portproxy add v4tov4 ^
  listenaddress=%LISTEN_IP% listenport=%LISTEN_PORT% ^
  connectaddress=%DEST_IP% connectport=%DEST_PORT%
if errorlevel 1 (
  echo [ERROR] Failed to add the rule. Try using an exact Listen IP instead of 0.0.0.0.
  pause
  goto menu
)

echo.
echo [OK] Rule added/updated.
pause
goto menu

:remove_one
cls
echo --- Remove one rule ---
set /p R_LISTEN_IP=Listen IP to remove [current %LISTEN_IP%]: 
if "%R_LISTEN_IP%"=="" set "R_LISTEN_IP=%LISTEN_IP%"
set /p R_LISTEN_PORT=Listen Port to remove [current %LISTEN_PORT%]: 
if "%R_LISTEN_PORT%"=="" set "R_LISTEN_PORT=%LISTEN_PORT%"
echo.
echo Deleting rule %R_LISTEN_IP%:%R_LISTEN_PORT% ...
netsh interface portproxy delete v4tov4 listenaddress=%R_LISTEN_IP% listenport=%R_LISTEN_PORT%
pause
goto menu

:remove_all
cls
echo --- Remove ALL rules ---
echo WARNING: This will delete ALL v4tov4 portproxy rules.
set /p confirm=Type YES to confirm: 
if /I not "%confirm%"=="YES" (
  echo Cancelled.
  pause
  goto menu
)
netsh interface portproxy reset
echo All rules removed.
pause
goto menu

:show_rules
cls
echo --- Current rules ---
netsh interface portproxy show all
echo.
pause
goto menu

:end
endlocal
exit /b 0
