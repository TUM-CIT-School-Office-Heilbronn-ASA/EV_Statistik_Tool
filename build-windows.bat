@echo off
setlocal enabledelayedexpansion
set "BUILD_FAILED=0"

echo ==========================================
echo   EV Statistik Tool - Windows Build Script
echo ==========================================
echo.

REM Check if R is installed
where R >nul 2>nul
if %errorlevel% neq 0 (
    echo [ERROR] R is not installed
    echo Please install R from: https://cran.r-project.org/bin/windows/base/
    set "BUILD_FAILED=1"
    goto :end
)

echo [OK] R found
R --version | findstr /C:"R version"

REM Check if Node.js is installed
where node >nul 2>nul
if %errorlevel% neq 0 (
    echo [ERROR] Node.js is not installed
    echo Please install Node.js from: https://nodejs.org/
    set "BUILD_FAILED=1"
    goto :end
)

echo [OK] Node.js found
node --version
echo [OK] npm found
call npm --version
echo.

REM Step 1: Verify package.json exists
if not exist "package.json" (
    echo [ERROR] package.json not found
    set "BUILD_FAILED=1"
    goto :end
)
echo [OK] Package.json found
echo.

REM Step 2: Check for portable R
if not exist "electron\R-portable" (
    echo [STEP] Portable R not found. Downloading...
    echo This will take 10-20 minutes...
    powershell -ExecutionPolicy Bypass -File scripts\download-r-portable.ps1
    if %errorlevel% neq 0 (
        echo [ERROR] Failed to download portable R
        set "BUILD_FAILED=1"
        goto :end
    )
    echo [OK] Portable R downloaded
) else (
    echo [OK] Portable R already exists
    for /f "tokens=3" %%a in ('dir /s /-c "electron\R-portable" ^| findstr /C:"bytes"') do set SIZE=%%a
    echo   Configured
)
echo.

REM Step 3: Install Node dependencies
if not exist "node_modules" (
    echo [STEP] Installing Node.js dependencies...
    call npm install
    if %errorlevel% neq 0 (
        echo [ERROR] Failed to install dependencies
        set "BUILD_FAILED=1"
        goto :end
    )
    echo [OK] Dependencies installed
) else (
    echo [OK] Node modules already installed
)
echo.

REM Step 4: Stop any running app instances that may lock the dist folder
echo [STEP] Stopping running app instances...
taskkill /F /IM "EV Statistik Tool.exe" /T >nul 2>nul
taskkill /F /IM "electron.exe" /T >nul 2>nul
powershell -NoProfile -Command "Start-Sleep -Seconds 2" >nul 2>nul
echo [OK] App instances stopped (if any)
echo.

REM Step 5: Clean previous builds
if exist "dist" (
    echo [STEP] Cleaning previous builds...
    rmdir /s /q dist
    echo [OK] Previous builds removed
)
echo.

REM Step 6: Build the app
echo [STEP] Building Windows application...
echo This may take 5-10 minutes...
echo.

call npm run build:win

if %errorlevel% neq 0 (
    echo.
    echo [ERROR] Build failed
    set "BUILD_FAILED=1"
    goto :end
)

echo.
echo ==========================================
echo   Build Complete!
echo ==========================================
echo.
echo Build outputs:
if exist "dist\EV Statistik Tool Setup 1.0.0.exe" (
    for %%A in ("dist\EV Statistik Tool Setup 1.0.0.exe") do (
        echo [OK] EV Statistik Tool Setup 1.0.0.exe (%%~zA bytes)
    )
)
if exist "dist\EV Statistik Tool 1.0.0.exe" (
    for %%A in ("dist\EV Statistik Tool 1.0.0.exe") do (
        echo [OK] EV Statistik Tool 1.0.0.exe (%%~zA bytes)
    )
)
echo.
echo Test the installer:
echo   "dist\EV Statistik Tool Setup 1.0.0.exe"
echo.
echo Or run portable version:
echo   "dist\EV Statistik Tool 1.0.0.exe"
echo.

:end
echo.
if "%BUILD_FAILED%"=="1" (
    echo [ERROR] Build failed. Review the output above.
) else (
    echo [OK] Script finished.
)
echo.
set "EXIT_CODE=%BUILD_FAILED%"
endlocal
exit /b %EXIT_CODE%
