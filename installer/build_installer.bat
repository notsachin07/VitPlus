@echo off
echo ========================================
echo    VitPlus Build and Package Script
echo ========================================
echo.

:: Set paths
set PROJECT_DIR=%~dp0..
set INSTALLER_DIR=%~dp0
set BUILD_DIR=%PROJECT_DIR%\build\windows\x64\runner\Release
set DIST_DIR=%PROJECT_DIR%\dist

:: Create dist directory
if not exist "%DIST_DIR%" mkdir "%DIST_DIR%"

:: Step 1: Build Flutter app in release mode
echo [1/3] Building Flutter app...
cd /d "%PROJECT_DIR%"
call flutter build windows --release
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Flutter build failed!
    pause
    exit /b 1
)
echo Flutter build complete.
echo.

:: Step 2: Build installer with Inno Setup
echo [2/3] Building installer...
cd /d "%INSTALLER_DIR%"

:: Try to find Inno Setup
set ISCC_PATH=
if exist "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" (
    set ISCC_PATH=C:\Program Files (x86)\Inno Setup 6\ISCC.exe
) else if exist "C:\Program Files\Inno Setup 6\ISCC.exe" (
    set ISCC_PATH=C:\Program Files\Inno Setup 6\ISCC.exe
) else (
    echo ERROR: Inno Setup not found! Please install Inno Setup 6.
    pause
    exit /b 1
)

"%ISCC_PATH%" vitplus_setup.iss
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Installer build failed!
    pause
    exit /b 1
)
echo Installer build complete.
echo.

:: Step 3: Create portable ZIP
echo [3/3] Creating portable ZIP...
cd /d "%BUILD_DIR%"
powershell -Command "Compress-Archive -Path '*' -DestinationPath '%DIST_DIR%\VitPlus_Portable.zip' -Force"
if %ERRORLEVEL% NEQ 0 (
    echo WARNING: Failed to create portable ZIP
) else (
    echo Portable ZIP created.
)
echo.

echo ========================================
echo    Build Complete!
echo ========================================
echo.
echo Output files:
echo   - %DIST_DIR%\VitPlus_Setup_*.exe (Installer)
echo   - %DIST_DIR%\VitPlus_Portable.zip (Portable)
echo.
echo For GitHub releases, upload both files.
echo.
pause
