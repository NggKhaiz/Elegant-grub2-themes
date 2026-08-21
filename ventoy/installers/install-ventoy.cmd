@echo off
rem ============================================================
rem  Raven Hub - Ventoy theme installer (double-click launcher)
rem
rem  This launches Windows PowerShell to run install-ventoy.ps1.
rem  '-ExecutionPolicy Bypass' applies to THIS process only; your
rem  system-wide PowerShell execution policy is never changed.
rem  Nothing here formats drives, repartitions, or needs admin.
rem ============================================================
setlocal
title Raven Hub - Ventoy theme installer
echo.
echo  Raven Hub - Ventoy theme installer
echo  ----------------------------------
echo  Starting PowerShell installer (process-local execution policy)...
echo.

where powershell.exe >nul 2>nul
if errorlevel 1 (
  echo  ERROR: powershell.exe was not found on this system.
  echo  See README-WINDOWS.md for the manual copy installation.
  pause
  exit /b 2
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0install-ventoy.ps1" %*
set EXITCODE=%ERRORLEVEL%

echo.
if "%EXITCODE%"=="0" (
  echo  Installer finished successfully. You can close this window.
) else (
  echo  Installer finished with exit code %EXITCODE%.
  echo  Please read the messages above. See README-WINDOWS.md for help.
)
pause
exit /b %EXITCODE%
