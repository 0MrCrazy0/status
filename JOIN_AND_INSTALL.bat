@echo off
setlocal EnableExtensions
rem ---------------------------------------------------------------------------
rem  Stats-UI: put downloaded installer PARTS back together, verify, install.
rem  You only need this if you downloaded the installer in parts. Normally just
rem  download Stats-UI-Setup-X.Y.Z.exe from the Releases page and double-click it.
rem
rem  Put ALL of these in ONE folder, then double-click this file:
rem    Stats-UI-Setup-X.Y.Z.exe.001, .002, ...   Stats-UI-Setup-X.Y.Z.exe.parts.txt
rem    StatsUI-Parts.ps1                         JOIN_AND_INSTALL.bat (this file)
rem ---------------------------------------------------------------------------
title Stats-UI - join parts and install
cd /d "%~dp0"
if not exist "%~dp0StatsUI-Parts.ps1" (
  echo StatsUI-Parts.ps1 is missing. Download it from the same place as the parts
  echo and put it in this folder: %~dp0
  goto :fail
)
rem Pass the folder as "%~dp0." - a path ending in \" would swallow the quote.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0StatsUI-Parts.ps1" -Join "%~dp0."
if errorlevel 1 goto :fail
exit /b 0

:fail
echo.
echo Nothing was installed.
pause
exit /b 1
