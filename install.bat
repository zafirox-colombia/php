@echo off
title PHP Manager Ultimate - Installation
color 0A
echo.
echo  ============================================
echo   PHP Manager Ultimate - Installation Script
echo  ============================================
echo.

:: Check if running as administrator
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [WARNING] This script is not running as Administrator.
    echo           Some features may not work properly.
    echo.
    pause
)

:: Set installation directory
set INSTALL_DIR=C:\php
echo [1/5] Creating installation directory: %INSTALL_DIR%
if not exist "%INSTALL_DIR%" mkdir "%INSTALL_DIR%"

:: Copy files
echo [2/5] Copying application files...
xcopy /E /I /Y "%~dp0app" "%INSTALL_DIR%\app" >nul
copy /Y "%~dp0php-manager.ps1" "%INSTALL_DIR%\" >nul
copy /Y "%~dp0config.json" "%INSTALL_DIR%\" >nul 2>nul

:: Create versions directory
echo [3/5] Creating versions directory...
if not exist "%INSTALL_DIR%\versions" mkdir "%INSTALL_DIR%\versions"

:: Create desktop shortcut
echo [4/5] Creating desktop shortcut...
powershell -Command "$WshShell = New-Object -ComObject WScript.Shell; $Shortcut = $WshShell.CreateShortcut([Environment]::GetFolderPath('Desktop') + '\PHP Manager.lnk'); $Shortcut.TargetPath = 'powershell.exe'; $Shortcut.Arguments = '-ExecutionPolicy Bypass -File \"C:\php\php-manager.ps1\"'; $Shortcut.WorkingDirectory = 'C:\php'; $Shortcut.IconLocation = 'shell32.dll,21'; $Shortcut.Save()"

:: Set execution policy for current user
echo [5/5] Configuring PowerShell execution policy...
powershell -Command "Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force" 2>nul

echo.
echo  ============================================
echo   Installation Complete!
echo  ============================================
echo.
echo  Location: %INSTALL_DIR%
echo  Shortcut: Desktop\PHP Manager.lnk
echo.
echo  To start: Double-click the desktop shortcut
echo            or run: powershell -File C:\php\php-manager.ps1
echo.
echo  First run will download PHP versions from php.net
echo.
pause
