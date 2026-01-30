# PowerShell script to download portable R for Windows
# Run this on Windows to prepare for building Windows installers

param(
    [string]$RVersion = "4.5.1",
    [string]$OutputDir = "electron\R-portable"
)

$ErrorActionPreference = "Stop"

Write-Host "=== Downloading Portable R for Windows ===" -ForegroundColor Green

# Required R packages
$Packages = @(
    "shiny",
    "shinydashboard",
    "shinyjs",
    "DT",
    "R6",
    "tidyverse",
    "checkmate",
    "glue",
    "here",
    "purrr",
    "zip",
    "png",
    "plotly",
    "htmlwidgets",
    "jsonlite",
    "readr",
    "stringr",
    "forcats",
    "scales",
    "lubridate",
    "e1071"
)

# Create output directory
Write-Host "Creating directory: $OutputDir"
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

# Check if R is installed
$RPath = (Get-Command R -ErrorAction SilentlyContinue).Source
if (-not $RPath) {
    $RscriptPath = (Get-Command Rscript -ErrorAction SilentlyContinue).Source
    if ($RscriptPath) {
        $RPath = $RscriptPath
    }
}
if (-not $RPath -and $Env:R_HOME) {
    $Candidates = @(
        (Join-Path $Env:R_HOME "bin\R.exe"),
        (Join-Path $Env:R_HOME "bin\x64\R.exe"),
        (Join-Path $Env:R_HOME "bin\Rscript.exe"),
        (Join-Path $Env:R_HOME "bin\x64\Rscript.exe")
    )
    foreach ($Candidate in $Candidates) {
        if (Test-Path $Candidate) {
            $RPath = $Candidate
            break
        }
    }
}
if (-not $RPath) {
    Write-Host "Error: R is not installed on this system." -ForegroundColor Red
    Write-Host "Please install R from https://cran.r-project.org/bin/windows/base/"
    exit 1
}

Write-Host "Found R at: $RPath"
$RBinDir = Split-Path -Parent $RPath
$RInstallPath = Split-Path -Parent $RBinDir
if ((Split-Path -Leaf $RBinDir) -ieq "x64") {
    $RInstallPath = Split-Path -Parent $RInstallPath
}
Write-Host "R installation path: $RInstallPath"
$SystemRscriptExe = $RPath
if (-not ((Split-Path -Leaf $RPath) -ieq "Rscript.exe")) {
    $Candidate = Join-Path $RBinDir "Rscript.exe"
    if (Test-Path $Candidate) {
        $SystemRscriptExe = $Candidate
    } else {
        $Candidate = Join-Path $RBinDir "x64\Rscript.exe"
        if (Test-Path $Candidate) {
            $SystemRscriptExe = $Candidate
        }
    }
}
if (-not (Test-Path $SystemRscriptExe)) {
    Write-Host "Error: Rscript not found next to R binary." -ForegroundColor Red
    exit 1
}

# Copy R installation
Write-Host "Copying R files..." -ForegroundColor Yellow
Copy-Item -Path "$RInstallPath\bin" -Destination "$OutputDir\bin" -Recurse -Force
Copy-Item -Path "$RInstallPath\library" -Destination "$OutputDir\library" -Recurse -Force
Copy-Item -Path "$RInstallPath\etc" -Destination "$OutputDir\etc" -Recurse -Force
Copy-Item -Path "$RInstallPath\include" -Destination "$OutputDir\include" -Recurse -Force -ErrorAction SilentlyContinue

# Install required packages
Write-Host "Installing required packages..." -ForegroundColor Yellow
$LibPath = Join-Path $OutputDir "library"
$LibPath = $LibPath -replace '\\', '/'
foreach ($package in $Packages) {
    Write-Host "Installing $package..."
    & $SystemRscriptExe -e "install.packages('$package', lib='$LibPath', repos='https://cran.rstudio.com/', dependencies=TRUE, quiet=FALSE, type='binary')"
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Warning: Failed to install $package" -ForegroundColor Yellow
    }
}

# Get size
$Size = (Get-ChildItem -Path $OutputDir -Recurse | Measure-Object -Property Length -Sum).Sum / 1MB
Write-Host ""
Write-Host "=== Portable R Setup Complete ===" -ForegroundColor Green
Write-Host "Location: $OutputDir"
Write-Host "Size: $([math]::Round($Size, 2)) MB"
Write-Host ""
Write-Host "Next steps:"
Write-Host "1. Install Node dependencies: npm install"
Write-Host "2. Build the app: npm run build:win"
