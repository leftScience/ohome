@echo off
setlocal
set "APP_DIR=%~dp0"
cd /d "%APP_DIR%"
set "OHOME_BASE_DIR=%APP_DIR%"
if exist "%APP_DIR%ohome-updater.exe" (
  start "" /B "%APP_DIR%ohome-updater.exe" >nul 2>&1
)
"%APP_DIR%ohome-updater.exe" run-current-server
