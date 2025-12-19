@echo off
title PHP Manager Ultimate - Smart Installer
color 0A
setlocal enabledelayedexpansion

echo.
echo  ============================================
echo   PHP Manager Ultimate - Smart Installer
echo  ============================================
echo.

:: Target directory (REQUIRED - NOT CONFIGURABLE)
set INSTALL_DIR=C:\php
set SOURCE_DIR=%~dp0

:: Check if running as administrator
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [!] WARNING: Not running as Administrator
    echo     Some features may not work properly.
    echo.
)

:: ============================================
:: STEP 1: Detect Installation Type
:: ============================================
echo [1/6] Analyzing installation...

set INSTALL_TYPE=fresh
set EXISTING_VERSIONS=0
set EXISTING_CURRENT=0

if exist "%INSTALL_DIR%" (
    set INSTALL_TYPE=upgrade
    echo       Found existing installation at %INSTALL_DIR%
    
    :: Check for existing PHP versions
    if exist "%INSTALL_DIR%\versions" (
        for /d %%i in ("%INSTALL_DIR%\versions\*") do (
            set /a EXISTING_VERSIONS+=1
        )
        echo       Found !EXISTING_VERSIONS! PHP version(s) installed
    )
    
    :: Check for current symlink
    if exist "%INSTALL_DIR%\current" (
        set EXISTING_CURRENT=1
        echo       Found active PHP version symlink
    )
    
    :: Check for config
    if exist "%INSTALL_DIR%\config.json" (
        echo       Found existing configuration
    )
) else (
    echo       Fresh installation detected
)

echo.
echo  Installation Type: %INSTALL_TYPE%
if %EXISTING_VERSIONS% gtr 0 (
    echo  PHP Versions Found: %EXISTING_VERSIONS% (will be preserved)
)
echo.

:: ============================================
:: STEP 2: Backup existing data (if upgrade)
:: ============================================
if "%INSTALL_TYPE%"=="upgrade" (
    echo [2/6] Preserving existing data...
    
    :: Create temp backup location
    set BACKUP_DIR=%TEMP%\php_manager_backup_%RANDOM%
    mkdir "!BACKUP_DIR!" 2>nul
    
    :: Backup versions folder
    if exist "%INSTALL_DIR%\versions" (
        echo       Backing up PHP versions...
        xcopy /E /I /H /Y "%INSTALL_DIR%\versions" "!BACKUP_DIR!\versions" >nul 2>&1
    )
    
    :: Backup current symlink info
    if exist "%INSTALL_DIR%\current" (
        echo       Backing up current symlink...
        xcopy /E /I /H /Y "%INSTALL_DIR%\current" "!BACKUP_DIR!\current" >nul 2>&1
    )
    
    :: Backup config
    if exist "%INSTALL_DIR%\config.json" (
        echo       Backing up configuration...
        copy /Y "%INSTALL_DIR%\config.json" "!BACKUP_DIR!\config.json" >nul 2>&1
    )
    
    :: Backup debug logs
    if exist "%INSTALL_DIR%\server_debug.log" (
        copy /Y "%INSTALL_DIR%\server_debug.log" "!BACKUP_DIR!\server_debug.log" >nul 2>&1
    )
    
    echo       Backup location: !BACKUP_DIR!
) else (
    echo [2/6] Skipping backup (fresh install)
)

:: ============================================
:: STEP 3: Create/Clean installation directory
:: ============================================
echo [3/6] Preparing installation directory...

if "%INSTALL_TYPE%"=="upgrade" (
    :: Remove old app files only, preserve versions/current/config
    if exist "%INSTALL_DIR%\app" (
        echo       Removing old application files...
        rmdir /S /Q "%INSTALL_DIR%\app" 2>nul
    )
    if exist "%INSTALL_DIR%\php-manager.ps1" (
        del /F /Q "%INSTALL_DIR%\php-manager.ps1" 2>nul
    )
) else (
    :: Fresh install - create directory
    if not exist "%INSTALL_DIR%" mkdir "%INSTALL_DIR%"
)

:: ============================================
:: STEP 4: Copy new files
:: ============================================
echo [4/6] Installing application files...

:: Copy app folder
if exist "%SOURCE_DIR%app" (
    echo       Copying app folder...
    xcopy /E /I /H /Y "%SOURCE_DIR%app" "%INSTALL_DIR%\app" >nul
)

:: Copy launcher
if exist "%SOURCE_DIR%php-manager.ps1" (
    echo       Copying launcher...
    copy /Y "%SOURCE_DIR%php-manager.ps1" "%INSTALL_DIR%\" >nul
)

:: Copy config only if not exists (preserve user settings)
if not exist "%INSTALL_DIR%\config.json" (
    if exist "%SOURCE_DIR%config.json" (
        echo       Creating default configuration...
        copy /Y "%SOURCE_DIR%config.json" "%INSTALL_DIR%\" >nul
    )
) else (
    echo       Preserving existing configuration
)

:: Copy README and LICENSE
if exist "%SOURCE_DIR%README.md" copy /Y "%SOURCE_DIR%README.md" "%INSTALL_DIR%\" >nul
if exist "%SOURCE_DIR%LICENSE" copy /Y "%SOURCE_DIR%LICENSE" "%INSTALL_DIR%\" >nul

:: ============================================
:: STEP 5: Restore preserved data (if upgrade)
:: ============================================
if "%INSTALL_TYPE%"=="upgrade" (
    echo [5/6] Restoring preserved data...
    
    :: Restore versions if backup exists and target doesn't
    if not exist "%INSTALL_DIR%\versions" (
        if exist "!BACKUP_DIR!\versions" (
            echo       Restoring PHP versions...
            xcopy /E /I /H /Y "!BACKUP_DIR!\versions" "%INSTALL_DIR%\versions" >nul 2>&1
        )
    )
    
    :: Restore current if backup exists and target doesn't
    if not exist "%INSTALL_DIR%\current" (
        if exist "!BACKUP_DIR!\current" (
            echo       Restoring current symlink...
            xcopy /E /I /H /Y "!BACKUP_DIR!\current" "%INSTALL_DIR%\current" >nul 2>&1
        )
    )
    
    :: Cleanup backup
    if exist "!BACKUP_DIR!" (
        rmdir /S /Q "!BACKUP_DIR!" 2>nul
    )
) else (
    echo [5/6] Creating directories...
    if not exist "%INSTALL_DIR%\versions" mkdir "%INSTALL_DIR%\versions"
)

:: ============================================
:: STEP 6: Create shortcuts and finalize
:: ============================================
echo [6/6] Creating shortcuts and finalizing...

:: Create desktop shortcut
powershell -Command "$WshShell = New-Object -ComObject WScript.Shell; $Shortcut = $WshShell.CreateShortcut([Environment]::GetFolderPath('Desktop') + '\PHP Manager.lnk'); $Shortcut.TargetPath = 'powershell.exe'; $Shortcut.Arguments = '-ExecutionPolicy Bypass -File \"C:\php\php-manager.ps1\"'; $Shortcut.WorkingDirectory = 'C:\php'; $Shortcut.IconLocation = 'shell32.dll,21'; $Shortcut.Save()" 2>nul

:: Set execution policy
powershell -Command "Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force" 2>nul

echo.
echo  ============================================
echo   Installation Complete!
echo  ============================================
echo.
echo  Location:     %INSTALL_DIR%
echo  Shortcut:     Desktop\PHP Manager.lnk
echo  Install Type: %INSTALL_TYPE%
if %EXISTING_VERSIONS% gtr 0 (
echo  PHP Versions: %EXISTING_VERSIONS% preserved
)
echo.
echo  To start: Double-click the desktop shortcut
echo            or run: powershell -File C:\php\php-manager.ps1
echo.
pause
