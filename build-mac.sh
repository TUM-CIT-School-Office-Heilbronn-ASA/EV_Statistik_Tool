#!/bin/bash
set -e

echo "======================================"
echo "  EV Statistik Tool - Mac Build Script"
echo "======================================"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if we're on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo -e "${RED}Error: This script must be run on macOS${NC}"
    exit 1
fi

# Check if R is installed
if ! command -v R &> /dev/null; then
    echo -e "${RED}Error: R is not installed${NC}"
    echo "Please install R from: https://cran.r-project.org/"
    exit 1
fi

echo -e "${BLUE}✓ R found:${NC} $(R --version | head -n1)"

# Check if Node.js is installed
if ! command -v node &> /dev/null; then
    echo -e "${RED}Error: Node.js is not installed${NC}"
    echo "Please install Node.js from: https://nodejs.org/"
    exit 1
fi

echo -e "${BLUE}✓ Node.js found:${NC} $(node --version)"
echo -e "${BLUE}✓ npm found:${NC} $(npm --version)"
echo ""

# Step 1: Verify package.json exists
if [ ! -f "package.json" ]; then
    echo -e "${RED}Error: package.json not found${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Package.json found${NC}"
echo ""

# Step 2: Check for portable R
if [ ! -d "electron/R-portable" ]; then
    echo -e "${YELLOW}→ Portable R not found. Downloading...${NC}"
    echo "This will take 10-20 minutes..."
    ./scripts/download-r-portable.sh
    echo -e "${GREEN}✓ Portable R downloaded${NC}"
else
    echo -e "${GREEN}✓ Portable R already exists${NC}"
    SIZE=$(du -sh electron/R-portable | cut -f1)
    echo "  Size: $SIZE"
fi
echo ""

# Step 3: Install Node dependencies
if [ ! -d "node_modules" ]; then
    echo -e "${YELLOW}→ Installing Node.js dependencies...${NC}"
    npm install
    echo -e "${GREEN}✓ Dependencies installed${NC}"
else
    echo -e "${GREEN}✓ Node modules already installed${NC}"
fi
echo ""

# Step 4: Clean previous builds
if [ -d "dist" ]; then
    echo -e "${YELLOW}→ Cleaning previous builds...${NC}"
    rm -rf dist
    echo -e "${GREEN}✓ Previous builds removed${NC}"
fi
echo ""

# Step 5: Build the app
echo -e "${BLUE}→ Building Mac application...${NC}"
echo "This may take 5-10 minutes..."
echo ""

npm run build:mac

echo ""
echo -e "${GREEN}======================================"
echo "  ✓ Build Complete!"
echo "======================================${NC}"
echo ""
echo "Build outputs:"
if [ -f "dist/EV Statistik Tool-1.0.0-arm64.dmg" ]; then
    SIZE_ARM=$(du -h "dist/EV Statistik Tool-1.0.0-arm64.dmg" | cut -f1)
    echo -e "${GREEN}✓${NC} dist/EV Statistik Tool-1.0.0-arm64.dmg ($SIZE_ARM)"
fi
if [ -f "dist/EV Statistik Tool-1.0.0.dmg" ]; then
    SIZE_X64=$(du -h "dist/EV Statistik Tool-1.0.0.dmg" | cut -f1)
    echo -e "${GREEN}✓${NC} dist/EV Statistik Tool-1.0.0.dmg ($SIZE_X64)"
fi
echo ""
echo "Test the app:"
echo "  open \"dist/mac-arm64/EV Statistik Tool.app\""
echo ""
echo "Install the app:"
echo "  open \"dist/EV Statistik Tool-1.0.0-arm64.dmg\""
echo ""
