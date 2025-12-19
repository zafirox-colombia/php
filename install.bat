@echo off
title PHP Manager Ultimate - Smart Installer
color 0A
setlocal enabledelayedexpansion

echo.
echo  ============================================
echo   PHP Manager Ultimate - Smart Installer v2.0
echo  ============================================
echo.

:: Configuration
set INSTALL_DIR=C:\php
set SOURCE_DIR=%~dp0

:: Check if running FROM the installation directory
set "SRC_CHECK=%SOURCE_DIR:~0,-1%"
if /I "%SRC_CHECK%"=="%INSTALL_DIR%" (
    echo [i] Running from install directory - already installed.
    echo     Use php-manager.ps1 to start.
    pause
    exit /b 0
)

:: Admin check
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [!] WARNING: Not running as Administrator
    echo.
)

:: ========== STEP 1: Detect Installation Type ==========
echo [1/6] Analyzing...

set INSTALL_TYPE=fresh
set VER_COUNT=0

if not exist "%INSTALL_DIR%" goto :step1_done

set INSTALL_TYPE=upgrade
echo       Existing installation found

if exist "%INSTALL_DIR%\versions" (
    for /d %%i in ("%INSTALL_DIR%\versions\*") do set /a VER_COUNT+=1
)
if !VER_COUNT! gtr 0 echo       - !VER_COUNT! PHP versions found

if exist "%INSTALL_DIR%\current" echo       - Active symlink found
if exist "%INSTALL_DIR%\config.json" echo       - Config found

:step1_done
echo.
echo  Type: %INSTALL_TYPE%
echo.

:: ========== STEP 2: Backup (upgrade only) ==========
if "%INSTALL_TYPE%"=="fresh" goto :step2_skip

echo [2/6] Backing up data...
set BACKUP_DIR=%TEMP%\php_backup_%RANDOM%
mkdir "%BACKUP_DIR%" 2>nul

if exist "%INSTALL_DIR%\versions" xcopy /E /I /H /Y /Q "%INSTALL_DIR%\versions" "%BACKUP_DIR%\versions" >nul 2>&1
if exist "%INSTALL_DIR%\current" xcopy /E /I /H /Y /Q "%INSTALL_DIR%\current" "%BACKUP_DIR%\current" >nul 2>&1
if exist "%INSTALL_DIR%\config.json" copy /Y "%INSTALL_DIR%\config.json" "%BACKUP_DIR%\" >nul 2>&1

echo       Backup created
goto :step2_end

:step2_skip
echo [2/6] Skipping backup

:step2_end

:: ========== STEP 3: Prepare Directory ==========
echo [3/6] Preparing directory...

if "%INSTALL_TYPE%"=="upgrade" (
    if exist "%INSTALL_DIR%\app" rmdir /S /Q "%INSTALL_DIR%\app" 2>nul
    if exist "%INSTALL_DIR%\php-manager.ps1" del /F /Q "%INSTALL_DIR%\php-manager.ps1" 2>nul
) else (
    mkdir "%INSTALL_DIR%" 2>nul
)

:: ========== STEP 4: Copy Files ==========
echo [4/6] Installing files...

if exist "%SOURCE_DIR%app" xcopy /E /I /H /Y /Q "%SOURCE_DIR%app" "%INSTALL_DIR%\app" >nul
if exist "%SOURCE_DIR%php-manager.ps1" copy /Y "%SOURCE_DIR%php-manager.ps1" "%INSTALL_DIR%\" >nul
if exist "%SOURCE_DIR%README.md" copy /Y "%SOURCE_DIR%README.md" "%INSTALL_DIR%\" >nul
if exist "%SOURCE_DIR%LICENSE" copy /Y "%SOURCE_DIR%LICENSE" "%INSTALL_DIR%\" >nul

if not exist "%INSTALL_DIR%\config.json" (
    if exist "%SOURCE_DIR%config.json" copy /Y "%SOURCE_DIR%config.json" "%INSTALL_DIR%\" >nul
)

:: ========== STEP 5: Restore Data ==========
if "%INSTALL_TYPE%"=="fresh" goto :step5_skip

echo [5/6] Restoring data...
if not exist "%INSTALL_DIR%\versions" (
    if exist "%BACKUP_DIR%\versions" xcopy /E /I /H /Y /Q "%BACKUP_DIR%\versions" "%INSTALL_DIR%\versions" >nul 2>&1
)
if not exist "%INSTALL_DIR%\current" (
    if exist "%BACKUP_DIR%\current" xcopy /E /I /H /Y /Q "%BACKUP_DIR%\current" "%INSTALL_DIR%\current" >nul 2>&1
)
if exist "%BACKUP_DIR%" rmdir /S /Q "%BACKUP_DIR%" 2>nul
goto :step5_end

:step5_skip
echo [5/6] Creating directories...
if not exist "%INSTALL_DIR%\versions" mkdir "%INSTALL_DIR%\versions"

:step5_end

:: ========== STEP 6: Finalize ==========
echo [6/6] Creating shortcut...

powershell -Command "$s = (New-Object -ComObject WScript.Shell).CreateShortcut([Environment]::GetFolderPath('Desktop') + '\PHP Manager.lnk'); $s.TargetPath = 'powershell.exe'; $s.Arguments = '-ExecutionPolicy Bypass -File \"C:\php\php-manager.ps1\"'; $s.WorkingDirectory = 'C:\php'; $s.IconLocation = 'shell32.dll,21'; $s.Save()" 2>nul

powershell -Command "Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force" 2>nul

echo.
echo  ============================================
echo   DONE!
echo  ============================================
echo.
echo  Location: %INSTALL_DIR%
echo  Shortcut: Desktop\PHP Manager.lnk
if !VER_COUNT! gtr 0 echo  PHP Versions preserved: !VER_COUNT!
echo.
echo  Double-click desktop shortcut to start
echo.
pause
