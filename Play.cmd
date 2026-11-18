@echo off
setlocal
set "ENGINE=godot.exe"
if defined GODOT_PATH if exist "%GODOT_PATH%" set "ENGINE=%GODOT_PATH%"
"%ENGINE%" --headless --path "%~dp0game" --import
if errorlevel 1 (
  pause
  exit /b 1
)
start "" "%ENGINE%" --path "%~dp0game"
