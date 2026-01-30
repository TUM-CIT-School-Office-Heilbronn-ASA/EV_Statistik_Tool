@echo off
setlocal enabledelayedexpansion

set "ROOT=%~dp0"
pushd "%ROOT%"

set "FORCE=0"
if /I "%~1"=="--force" set "FORCE=1"
if /I "%~1"=="-f" set "FORCE=1"

set "USE_GIT=0"
if exist ".git" (
    where git >nul 2>nul
    if %errorlevel%==0 set "USE_GIT=1"
)

if "%USE_GIT%"=="1" (
    echo Using git clean to remove ignored files.
    call :confirm
    if errorlevel 1 goto :canceled
    git clean -fdX
    goto :done
)

echo Git not available; removing common build artifacts.
call :confirm
if errorlevel 1 goto :canceled

for %%P in (
    "node_modules"
    "dist"
    "out"
    "electron\R-portable"
    "temp_r_download"
    ".tmp"
    "lint.log"
    "npm-debug.log*"
    "yarn-debug.log*"
    "yarn-error.log*"
    "*.blockmap"
    "*.dmg"
    "*.exe"
    "*.AppImage"
    "*.deb"
    "*.zip"
    "*.tar.gz"
    "*.Rcheck"
    "docs"
    ".Rproj.user"
    "rsconnect"
    "vignettes\*.html"
    "vignettes\*.pdf"
    ".Rhistory"
    ".Rapp.history"
    ".RData"
    ".RDataTmp"
    ".Ruserdata"
    ".Renviron"
    "package-lock.json"
    "package-shiny.json"
    "cache"
    "*_cache"
    "*.utf8.md"
    "*.knit.md"
    ".DS_Store"
    "Thumbs.db"
) do (
    call :remove "%%~P"
)

echo Cleanup complete.
goto :done

:remove
set "TARGET=%~1"
if exist "%TARGET%" (
    rmdir /s /q "%TARGET%" 2>nul
    del /f /q "%TARGET%" 2>nul
)
exit /b 0

:confirm
if "%FORCE%"=="1" exit /b 0
set /p "REPLY=This will delete ignored/build artifacts. Continue? [y/N] "
if /I "%REPLY%"=="y" exit /b 0
if /I "%REPLY%"=="yes" exit /b 0
exit /b 1

:canceled
echo Cleanup canceled.

:done
popd
endlocal
