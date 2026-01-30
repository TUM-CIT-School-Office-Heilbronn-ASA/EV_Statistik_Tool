#!/bin/bash
set -e

echo "=== Downloading Portable R for macOS ==="

# Configuration
R_VERSION="4.5.1"
OUTPUT_DIR="electron/R-portable"
TEMP_DIR="temp_r_download"

# Required R packages
PACKAGES=(
  "shiny"
  "shinydashboard"
  "shinyjs"
  "DT"
  "R6"
  "tidyverse"
  "checkmate"
  "glue"
  "here"
  "purrr"
  "zip"
  "png"
  "plotly"
  "htmlwidgets"
  "jsonlite"
  "readr"
  "stringr"
  "forcats"
  "scales"
  "lubridate"
  "e1071"
)

echo "Creating directories..."
mkdir -p "$OUTPUT_DIR"
mkdir -p "$TEMP_DIR"

# Check if R is installed
if ! command -v R &> /dev/null; then
    echo "Error: R is not installed on this system."
    echo "Please install R from https://cran.r-project.org/"
    exit 1
fi

echo "Detected R version: $(R --version | head -n1)"

# For macOS, copy the R framework
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "Copying R framework for macOS..."
    
    R_FRAMEWORK="/Library/Frameworks/R.framework"
    
    if [ ! -d "$R_FRAMEWORK" ]; then
        echo "Error: R framework not found at $R_FRAMEWORK"
        exit 1
    fi
    
    # Copy essential R files
    echo "Copying R binaries..."
    mkdir -p "$OUTPUT_DIR/bin"
    cp -R "$R_FRAMEWORK/Resources/bin/R" "$OUTPUT_DIR/bin/"
    cp -R "$R_FRAMEWORK/Resources/bin/Rscript" "$OUTPUT_DIR/bin/"
    
    echo "Copying R libraries..."
    mkdir -p "$OUTPUT_DIR/library"
    cp -R "$R_FRAMEWORK/Resources/library/"* "$OUTPUT_DIR/library/"
    
    echo "Copying R includes and other resources..."
    mkdir -p "$OUTPUT_DIR/include"
    mkdir -p "$OUTPUT_DIR/etc"
    cp -R "$R_FRAMEWORK/Resources/include/"* "$OUTPUT_DIR/include/" 2>/dev/null || true
    cp -R "$R_FRAMEWORK/Resources/etc/"* "$OUTPUT_DIR/etc/" 2>/dev/null || true
    
    # Make binaries executable
    chmod +x "$OUTPUT_DIR/bin/R"
    chmod +x "$OUTPUT_DIR/bin/Rscript"
    
    echo "Installing required packages..."
    for package in "${PACKAGES[@]}"; do
        echo "Installing $package..."
        "$OUTPUT_DIR/bin/Rscript" -e "install.packages('$package', lib='$OUTPUT_DIR/library', repos='https://cran.rstudio.com/', dependencies=TRUE, quiet=FALSE)"
    done
    
    echo "macOS portable R created successfully in $OUTPUT_DIR"
    echo "Size: $(du -sh "$OUTPUT_DIR" | cut -f1)"
    
elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" ]]; then
    echo "For Windows, please run download-r-portable.ps1 instead"
    exit 1
else
    echo "Unsupported OS: $OSTYPE"
    exit 1
fi

echo ""
echo "=== Portable R Setup Complete ==="
echo "Location: $OUTPUT_DIR"
echo ""
echo "Next steps:"
echo "1. For Windows builds, run: ./scripts/download-r-portable.ps1"
echo "2. Install dependencies: npm install"
echo "3. Build the app: npm run build:mac"
