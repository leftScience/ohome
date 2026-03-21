@echo off
setlocal
set "APP_DIR=%~dp0"
cd /d "%APP_DIR%"
set "OHOME_BASE_DIR=%APP_DIR%"
start "" "%APP_DIR%ohome.exe"
