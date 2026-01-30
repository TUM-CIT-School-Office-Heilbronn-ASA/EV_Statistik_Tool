# EV Statistik Tool - Electron Build Guide

This guide explains how to build standalone desktop applications for Windows and macOS without requiring R installation or admin rights.

## Prerequisites

- Node.js (v16 or higher) - [Download](https://nodejs.org/)
- R installed locally (only for building, not for end users)
- **For Mac builds:** macOS with Xcode Command Line Tools
- **For Windows builds:** Windows with Build Tools or Visual Studio

## Quick Start

### 1. Install Node Dependencies

```bash
# Install dependencies
npm install
```

### 2. Download Portable R

#### On macOS:
```bash
chmod +x scripts/download-r-portable.sh
./scripts/download-r-portable.sh
```

This creates `electron/R-portable/` with:
- R runtime (~150 MB)
- All required packages
- Binaries and libraries

#### On Windows:
```powershell
powershell -ExecutionPolicy Bypass -File scripts/download-r-portable.ps1
```

### 3. Add Application Icons (Optional but Recommended)

Create icons and place them in `electron/build/`:
- **macOS:** `icon.icns` (512x512 or larger)
- **Windows:** `icon.ico` (256x256 or larger)
- **Linux:** `icon.png` (512x512)

You can create these from a PNG using online tools:
- https://cloudconvert.com/png-to-icns
- https://cloudconvert.com/png-to-ico

### 4. Build the Application

#### Build for macOS:
```bash
npm run build:mac
```

Output: `dist/EV Statistik Tool-1.0.0.dmg`

#### Build for Windows (on Windows):
```bash
npm run build:win
```

Output: 
- `dist/EV Statistik Tool Setup 1.0.0.exe` (installer)
- `dist/EV Statistik Tool 1.0.0.exe` (portable)

#### Build for Both (requires both platforms or CI/CD):
```bash
npm run build:all
```

## Testing Before Building

Test the Electron app without building:

```bash
npm start
```

This runs in development mode using your local R installation.

## Distribution

### macOS (.dmg)
- **Size:** ~180-220 MB
- **Installation:** Drag & drop to Applications
- **Admin Required:** No
- **Gatekeeper:** Users need to right-click → Open on first launch (unless you code-sign)

### Windows (Installer)
- **Size:** ~150-200 MB
- **Installation:** Run setup, installs to `%LOCALAPPDATA%\Programs\`
- **Admin Required:** No
- **SmartScreen:** May show warning on first launch (unless you code-sign)

### Windows (Portable)
- **Size:** ~150-200 MB
- **Installation:** None, extract and run
- **Admin Required:** No

## Troubleshooting

### "R not found" during build
- Ensure R is installed on your build machine
- Check that `R` command works in terminal
- macOS: R should be at `/Library/Frameworks/R.framework/`
- Windows: R should be in PATH

### Portable R too large
The portable R includes all dependencies. To reduce size:
1. Remove unused packages from `download-r-portable.sh`
2. Run the script again
3. Rebuild

### App won't start
1. Check console logs (Cmd+Option+I on Mac, F12 on Windows)
2. Verify `electron/R-portable/` exists and has correct structure
3. Test with `npm start` first

### Port already in use
The app uses port 3838. If another app uses this port:
1. Change `PORT` constant in `electron/electron-main.js`
2. Rebuild the app

## Code Signing (Optional)

To avoid security warnings:

### macOS:
```bash
# Requires Apple Developer Account ($99/year)
npm install --save-dev electron-notarize
# Add notarization to build config
```

### Windows:
```bash
# Requires code signing certificate
# Add to package.json build.win:
"certificateFile": "path/to/cert.pfx",
"certificatePassword": "password"
```

## Customization

### Change App Name
Edit `package.json`:
```json
"build": {
  "productName": "Your App Name"
}
```

### Change Window Size
Edit `electron/electron-main.js`:
```javascript
mainWindow = new BrowserWindow({
  width: 1600,  // Change this
  height: 1000  // Change this
});
```

### Add Menu Bar
Add to `electron/electron-main.js`:
```javascript
const { Menu } = require('electron');

const menu = Menu.buildFromTemplate([
  {
    label: 'File',
    submenu: [
      { role: 'quit' }
    ]
  }
]);

Menu.setApplicationMenu(menu);
```

## CI/CD (GitHub Actions Example)

```yaml
name: Build
on: [push]
jobs:
  build-mac:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-node@v3
      - uses: r-lib/actions/setup-r@v2
      - run: ./scripts/download-r-portable.sh
      - run: npm install
      - run: npm run build:mac
      - uses: actions/upload-artifact@v3
        with:
          name: mac-dmg
          path: dist/*.dmg
  
  build-windows:
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-node@v3
      - uses: r-lib/actions/setup-r@v2
      - run: ./scripts/download-r-portable.ps1
      - run: npm install
      - run: npm run build:win
      - uses: actions/upload-artifact@v3
        with:
          name: windows-installer
          path: dist/*.exe
```

## File Structure After Build

```
dist/
├── EV Statistik Tool-1.0.0.dmg          # Mac installer
├── EV Statistik Tool Setup 1.0.0.exe    # Windows installer  
└── EV Statistik Tool 1.0.0.exe          # Windows portable

EV Statistik Tool.app/                   # Unpacked Mac app
└── Contents/
    ├── MacOS/
    │   └── EV Statistik Tool            # Electron binary
    └── Resources/
        ├── app.asar                    # Your app code
        └── R-portable/                 # Bundled R
```

## Support

For issues or questions:
1. Check console logs in the app (Help → Toggle Developer Tools)
2. Review this guide
3. Check Electron Builder docs: https://www.electron.build/

## Next Steps

1. Test the built app on a clean machine (no R installed)
2. Get feedback from users
3. Consider code signing for production
4. Set up automatic updates with electron-updater
