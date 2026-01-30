const { app, BrowserWindow, dialog, Menu } = require('electron');
const { spawn } = require('child_process');
const fs = require('fs');
const path = require('path');
const http = require('http');
const net = require('net');
const util = require('util');
const os = require('os');

// Handle creating/removing shortcuts on Windows when installing/uninstalling
if (require('electron-squirrel-startup')) {
  app.quit();
}

let rProcess = null;
let mainWindow = null;
let splashWindow = null;
let logFileStream = null;
let logFilePath = null;
let currentPort = 3838;
const DEFAULT_PORT = 3838;
const isDev = process.argv.includes('--dev');
let rendererReady = false;
const logBuffer = [];
const MAX_LOG_LINES = 500;
const SHINY_STARTUP_TIMEOUT_MS = 120000;
const SHINY_POLL_INTERVAL_MS = 500;
const GRACEFUL_SHUTDOWN_TIMEOUT_MS = 5000;
let pendingSplashStatus = 'Starting...';
let isShuttingDown = false;
let rProcessStarted = false;
let rProcessExited = false;
const disableSplash = process.argv.includes('--no-splash');
const startupLogBase = process.env.LOCALAPPDATA || os.tmpdir();
const startupLogPath = path.join(startupLogBase, 'EV-Statistik-Tool-startup.log');

function writeStartupLog(message) {
  try {
    fs.appendFileSync(startupLogPath, `[${new Date().toISOString()}] ${message}\n`);
  } catch (e) {
    // Ignore startup log failures
  }
}

writeStartupLog(`Process start. logPath=${startupLogPath} argv=${JSON.stringify(process.argv)}`);

function buildAppMenu() {
  const isMac = process.platform === 'darwin';
  const template = [
    ...(isMac
      ? [{
          label: app.name,
          submenu: [
            { role: 'about' },
            { type: 'separator' },
            { role: 'services' },
            { type: 'separator' },
            { role: 'hide' },
            { role: 'hideOthers' },
            { role: 'unhide' },
            { type: 'separator' },
            { role: 'quit' }
          ]
        }]
      : []),
    { role: 'editMenu' },
    {
      label: 'Help',
      submenu: [
        {
          label: 'Toggle Developer Tools',
          accelerator: isMac ? 'Alt+Cmd+I' : 'F12',
          click: () => {
            const win = BrowserWindow.getFocusedWindow() || mainWindow;
            if (win && !win.isDestroyed()) {
              win.webContents.toggleDevTools();
              win.webContents.focus();
            }
          }
        }
      ]
    }
  ];

  Menu.setApplicationMenu(Menu.buildFromTemplate(template));
}

function canSendToWindow(win) {
  return win
    && !win.isDestroyed()
    && win.webContents
    && !win.webContents.isDestroyed();
}

function canSendToRenderer() {
  return rendererReady && canSendToWindow(mainWindow);
}

function sendLogToRenderer(level, message) {
  if (!canSendToRenderer()) {
    return;
  }

  mainWindow.webContents
    .executeJavaScript(`console.${level}(${JSON.stringify(message)})`, true)
    .catch(() => {});
}

function setSplashStatus(message) {
  pendingSplashStatus = message;
  if (!canSendToWindow(splashWindow)) {
    return;
  }

  splashWindow.webContents
    .executeJavaScript(`window.__setStatus(${JSON.stringify(message)})`, true)
    .catch(() => {});
}

function sendLogToFile(level, message) {
  if (!logFileStream) {
    return;
  }

  const timestamp = new Date().toISOString();
  logFileStream.write(`[${timestamp}] [${level}] ${message}\n`);
}

function enqueueLog(level, source, args) {
  const message = `[${source}] ${util.format(...args)}`;
  logBuffer.push({ level, message });
  if (logBuffer.length > MAX_LOG_LINES) {
    logBuffer.shift();
  }
  sendLogToRenderer(level, message);
  sendLogToFile(level, message);
}

function flushBufferedLogs() {
  if (!canSendToRenderer()) {
    return;
  }

  for (const entry of logBuffer) {
    sendLogToRenderer(entry.level, entry.message);
  }
}

function flushBufferedLogsToFile() {
  if (!logFileStream) {
    return;
  }

  for (const entry of logBuffer) {
    sendLogToFile(entry.level, entry.message);
  }
}

function logInfo(source, ...args) {
  console.log(...args);
  enqueueLog('log', source, args);
}

function logError(source, ...args) {
  console.error(...args);
  enqueueLog('error', source, args);
}

// Get paths based on whether we're in development or production
function getPaths() {
  if (isDev) {
    // Development: use system R installation based on platform
    let rBin;
    if (process.platform === 'darwin') {
      rBin = '/Library/Frameworks/R.framework/Resources/bin/R';
    } else if (process.platform === 'win32') {
      // Common Windows R installation paths
      const possiblePaths = [
        'C:\\Program Files\\R\\R-4.5.1\\bin\\x64\\R.exe',
        'C:\\Program Files\\R\\R-4.5.0\\bin\\x64\\R.exe',
        'C:\\Program Files\\R\\R-4.4.1\\bin\\x64\\R.exe',
        'C:\\Program Files\\R\\R-4.4.0\\bin\\x64\\R.exe',
        'C:\\Program Files\\R\\R-4.3.0\\bin\\x64\\R.exe',
        'C:\\Program Files\\R\\R-4.2.0\\bin\\x64\\R.exe',
        'C:\\Program Files\\R\\R-4.1.0\\bin\\x64\\R.exe'
      ];
      rBin = possiblePaths.find(p => fs.existsSync(p)) || 'R.exe'; // Fall back to PATH
    } else {
      // Linux: R is typically in PATH
      rBin = '/usr/bin/R';
    }
    return {
      rBin: rBin,
      appPath: path.join(__dirname, '..')
    };
  } else {
    // Production: use bundled R
    const isPackaged = app.isPackaged;
    const resourcesPath = isPackaged 
      ? process.resourcesPath 
      : path.join(__dirname, '..');
    
    const platform = process.platform;
    let rBin;
    
    if (platform === 'darwin') {
      rBin = path.join(resourcesPath, 'R-portable', 'bin', 'R');
    } else if (platform === 'win32') {
      const rBinCandidates = [
        path.join(resourcesPath, 'R-portable', 'bin', 'x64', 'Rterm.exe'),
        path.join(resourcesPath, 'R-portable', 'bin', 'x64', 'R.exe')
      ];
      rBin = rBinCandidates.find(p => fs.existsSync(p)) || rBinCandidates[0];
    } else {
      rBin = path.join(resourcesPath, 'R-portable', 'bin', 'R');
    }
    
    // App path should be the directory containing app.R
    return {
      rBin: rBin,
      appPath: resourcesPath
    };
  }
}

// Check if a port is available
function isPortAvailable(port) {
  return new Promise((resolve) => {
    let server;
    try {
      server = net.createServer();
      server.once('error', () => {
        resolve(false);
      });
      server.once('listening', () => {
        // Wait for server to fully close before resolving
        server.close(() => {
          resolve(true);
        });
      });
      server.listen(port, '127.0.0.1');
    } catch (e) {
      // Handle synchronous errors
      if (server) {
        try {
          server.close();
        } catch (closeErr) {
          // Ignore close errors
        }
      }
      resolve(false);
    }
  });
}

// Find an available port starting from the default
async function findAvailablePort(startPort = DEFAULT_PORT, maxAttempts = 10) {
  const MIN_PORT = 1024; // First non-privileged port
  const MAX_PORT = 65535;

  if (startPort < MIN_PORT) {
    throw new Error(`Start port ${startPort} is in privileged range (< ${MIN_PORT})`);
  }

  for (let i = 0; i < maxAttempts; i++) {
    const port = startPort + i;
    if (port > MAX_PORT) {
      throw new Error(`Port ${port} exceeds maximum valid port number (${MAX_PORT})`);
    }
    const available = await isPortAvailable(port);
    if (available) {
      return port;
    }
    logInfo('main', `Port ${port} is in use, trying next port...`);
  }
  throw new Error(`No available port found after ${maxAttempts} attempts starting from ${startPort}`);
}

// Check if Shiny server is running
function checkShinyServer(port, callback, startedAt = Date.now()) {
  // Stop checking if app is shutting down
  if (isShuttingDown) {
    callback(false);
    return;
  }

  const req = http.get(`http://127.0.0.1:${port}`, (res) => {
    // Consume the response to free up resources
    res.resume();
    // Accept 200 and redirects (3xx) as success indicators
    if (res.statusCode === 200 || (res.statusCode >= 300 && res.statusCode < 400)) {
      callback(true);
    } else {
      retryCheck();
    }
  });

  req.on('error', () => {
    retryCheck();
  });

  // Set a timeout for individual requests
  req.setTimeout(5000, () => {
    req.destroy();
    retryCheck();
  });

  function retryCheck() {
    // Stop retrying if app is shutting down
    if (isShuttingDown) {
      callback(false);
      return;
    }
    if (Date.now() - startedAt < SHINY_STARTUP_TIMEOUT_MS) {
      setTimeout(() => checkShinyServer(port, callback, startedAt), SHINY_POLL_INTERVAL_MS);
    } else {
      callback(false);
    }
  }
}

// Sanitize path for use in R command (prevent command injection)
function sanitizePathForR(inputPath) {
  // Normalize the path and ensure it's absolute
  const normalizedPath = path.resolve(inputPath);
  // Escape special characters for R string literals
  return normalizedPath
    .replace(/\\/g, '/')
    .replace(/'/g, "\\'")
    .replace(/\n/g, '\\n')
    .replace(/\r/g, '\\r')
    .replace(/\t/g, '\\t');
}

// Start R Shiny server
async function startRShiny() {
  const paths = getPaths();

  logInfo('main', 'Starting R Shiny server...');
  logInfo('main', 'R binary:', paths.rBin);
  logInfo('main', 'App path:', paths.appPath);

  // Find an available port
  try {
    currentPort = await findAvailablePort(DEFAULT_PORT);
    logInfo('main', `Using port: ${currentPort}`);
  } catch (portError) {
    throw new Error(`Failed to find available port: ${portError.message}`);
  }

  // Sanitize the app path to prevent command injection
  const sanitizedAppPath = sanitizePathForR(paths.appPath);

  return new Promise((resolve, reject) => {
    let resolved = false;

    const safeResolve = () => {
      if (!resolved) {
        resolved = true;
        rProcessStarted = true;
        resolve();
      }
    };

    const safeReject = (error) => {
      if (!resolved) {
        resolved = true;
        rProcessStarted = false; // Ensure flag is false on startup failure
        reject(error);
      }
    };

    const rCmd = `
      options(shiny.port = ${currentPort}, shiny.host = '127.0.0.1');
      setwd('${sanitizedAppPath}');
      shiny::runApp(launch.browser = FALSE)
    `;

    rProcess = spawn(paths.rBin, [
      '--vanilla',
      '--quiet',
      '-e',
      rCmd
    ], {
      cwd: paths.appPath
    });

    rProcess.stdout.on('data', (data) => {
      logInfo('R', `stdout: ${data}`);
      if (data.toString().includes('Listening on')) {
        safeResolve();
      }
    });

    rProcess.stderr.on('data', (data) => {
      logError('R', `stderr: ${data}`);
    });

    rProcess.on('error', (error) => {
      logError('main', 'Failed to start R process:', error);
      safeReject(error);
    });

    rProcess.on('close', (code) => {
      rProcessExited = true;
      logInfo('main', `R process exited with code ${code}`);
      if (!resolved && code !== 0) {
        safeReject(new Error(`R process exited with code ${code}`));
      }
      // Handle R process crash after successful startup
      if (rProcessStarted && !isShuttingDown) {
        logError('main', 'R process crashed unexpectedly');
        handleRProcessCrash();
      }
    });

    // Fallback: check if server is running even if we don't see the log
    checkShinyServer(currentPort, (isRunning) => {
      if (isRunning) {
        safeResolve();
      } else {
        safeReject(new Error('R Shiny server did not start within timeout'));
      }
    });

  });
}

// Handle R process crash after startup
function handleRProcessCrash() {
  if (isShuttingDown) return;

  rProcessStarted = false;
  rProcess = null;

  if (mainWindow && !mainWindow.isDestroyed()) {
    dialog.showMessageBox(mainWindow, {
      type: 'error',
      title: 'Backend Error',
      message: 'The R backend process has crashed unexpectedly.',
      detail: 'The application needs to be restarted.',
      buttons: ['Quit']
    }).then(() => {
      app.quit();
    });
  } else {
    dialog.showErrorBox('Backend Error', 'The R backend process has crashed unexpectedly. The application will now close.');
    app.quit();
  }
}

// Create the main window
function createWindow() {
  rendererReady = false;
  mainWindow = new BrowserWindow({
    width: 1400,
    height: 900,
    minWidth: 800,
    minHeight: 600,
    webPreferences: {
      nodeIntegration: false,
      contextIsolation: true,
      preload: path.join(__dirname, 'preload.js')
    },
    title: 'EV Statistik Tool',
    show: false // Don't show until ready
  });
  
  // Show window when ready
  mainWindow.once('ready-to-show', () => {
    mainWindow.show();
    closeStartupWindows();
  });

  mainWindow.webContents.on('did-finish-load', () => {
    rendererReady = true;
    flushBufferedLogs();
  });
  
  // Load the Shiny app
  mainWindow.loadURL(`http://127.0.0.1:${currentPort}`)
    .catch((err) => {
      logError('main', 'Failed to load Shiny app URL:', err);
      dialog.showErrorBox('Loading Error',
        'Failed to load the application. The R server may have stopped.');
    });

  // Open DevTools in development mode
  if (isDev) {
    mainWindow.webContents.openDevTools();
  }
  
  // Handle window closed
  mainWindow.on('closed', () => {
    mainWindow = null;
    rendererReady = false;
  });
  
  // Prevent navigation away from the app
  mainWindow.webContents.on('will-navigate', (event, url) => {
    if (!url.startsWith(`http://127.0.0.1:${currentPort}`)) {
      event.preventDefault();
    }
  });
}

function createSplashWindow() {
  if (disableSplash) {
    writeStartupLog('Splash disabled via --no-splash.');
    return;
  }
  splashWindow = new BrowserWindow({
    width: 520,
    height: 340,
    resizable: false,
    minimizable: false,
    maximizable: false,
    show: true,
    frame: false,
    backgroundColor: '#0b0f14',
    skipTaskbar: false,
    alwaysOnTop: true,
    webPreferences: {
      nodeIntegration: false,
      contextIsolation: true
    }
  });

  splashWindow.setMenuBarVisibility(false);
  splashWindow.loadFile(path.join(__dirname, 'splash.html'))
    .catch((err) => {
      logError('main', 'Failed to load splash screen:', err);
      // Splash is optional, so continue without it
    });
  splashWindow.once('ready-to-show', () => {
    if (splashWindow) {
      splashWindow.center();
      splashWindow.show();
      splashWindow.focus();
    }
  });
  splashWindow.webContents.on('did-finish-load', () => {
    setSplashStatus(pendingSplashStatus);
  });
  splashWindow.on('closed', () => {
    splashWindow = null;
  });
}

function closeStartupWindows() {
  if (splashWindow && !splashWindow.isDestroyed()) {
    splashWindow.hide();
    splashWindow.destroy();
    splashWindow = null;
  }
}

function logSystemInfo() {
  logInfo('main', '=== System Information ===');
  logInfo('main', `OS: ${os.type()} ${os.release()} (${os.platform()})`);
  logInfo('main', `Architecture: ${os.arch()}`);
  logInfo('main', `Node.js: ${process.version}`);
  logInfo('main', `Electron: ${process.versions.electron}`);
  logInfo('main', `Chrome: ${process.versions.chrome}`);
  logInfo('main', `Total Memory: ${Math.round(os.totalmem() / (1024 * 1024 * 1024))} GB`);
  logInfo('main', `Free Memory: ${Math.round(os.freemem() / (1024 * 1024 * 1024))} GB`);
  logInfo('main', `App Version: ${app.getVersion()}`);
  logInfo('main', `App Path: ${app.getAppPath()}`);
  logInfo('main', `Is Packaged: ${app.isPackaged}`);
  logInfo('main', '==========================');
}

function initLogFile() {
  // Use userData directory for logs (always writable across platforms)
  // Falls back to exe directory if userData is not available
  let logDir;
  try {
    logDir = app.getPath('userData');
  } catch (e) {
    logDir = app.isPackaged
      ? path.dirname(app.getPath('exe'))
      : path.join(__dirname, '..');
  }
  logFilePath = path.join(logDir, 'EV-Statistik-Tool.log');
  logFileStream = fs.createWriteStream(logFilePath, { flags: 'a' });

  logFileStream.on('error', (error) => {
    console.error('Failed to write log file:', error);
    // Attempt to flush any buffered data before closing
    if (logFileStream) {
      try {
        logFileStream.end();
      } catch (e) {
        // Ignore errors during cleanup
      }
    }
    logFileStream = null;
  });

  flushBufferedLogsToFile();
  logInfo('main', 'Logging to file:', logFilePath);
}

// Track if initial startup is complete
let startupComplete = false;

// Handle macOS dock click - must be registered before whenReady
app.on('activate', () => {
  // Only create window if startup is complete, R is running, and no windows exist
  if (startupComplete && rProcessStarted && BrowserWindow.getAllWindows().length === 0) {
    createWindow();
  }
});

// App ready
app.whenReady().then(async () => {
  try {
    writeStartupLog('App whenReady.');
    buildAppMenu();
    initLogFile();
    logSystemInfo();
    createSplashWindow();
    logInfo('main', 'App is ready, starting R Shiny server...');
    setSplashStatus('Starting R Shiny server...');
    await startRShiny();
    logInfo('main', 'R Shiny server started successfully');
    setSplashStatus('Launching EV Statistik Tool...');
    createWindow();
    startupComplete = true;
  } catch (error) {
    writeStartupLog(`Startup error: ${error.message}`);
    logError('main', 'Failed to start application:', error);
    // Close splash window before showing error dialog
    closeStartupWindows();
    dialog.showErrorBox(
      'Startup Error',
      `Failed to start the application:\n${error.message}\n\nPlease check the console for more details.`
    );
    app.quit();
  }
});

// Quit when all windows are closed
app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') {
    app.quit();
  }
});

// Platform-specific process termination
function killRProcess(force = false) {
  if (!rProcess) return;

  const pid = rProcess.pid;
  if (process.platform === 'win32') {
    // Windows: use taskkill for reliable termination
    // /T kills child processes, /F forces termination
    const args = force ? ['/pid', pid.toString(), '/T', '/F'] : ['/pid', pid.toString(), '/T'];
    const taskkill = spawn('taskkill', args);
    taskkill.on('error', (err) => {
      logError('main', 'taskkill failed:', err);
    });
    taskkill.on('exit', (code) => {
      if (code !== 0 && code !== null) {
        logError('main', `taskkill exited with code ${code}`);
      }
    });
  } else {
    // Unix: use signals
    rProcess.kill(force ? 'SIGKILL' : 'SIGTERM');
  }
}

// Clean up R process on quit
app.on('will-quit', () => {
  isShuttingDown = true;

  if (rProcess) {
    logInfo('main', 'Killing R process...');
    killRProcess(false);

    // Force kill after graceful timeout if still running
    setTimeout(() => {
      if (rProcess && !rProcessExited) {
        logInfo('main', 'Force killing R process...');
        killRProcess(true);
      }
    }, GRACEFUL_SHUTDOWN_TIMEOUT_MS);
  }

  if (logFileStream) {
    logFileStream.end();
    logFileStream = null;
  }
});

// Handle uncaught exceptions
process.on('uncaughtException', (error) => {
  writeStartupLog(`Uncaught exception: ${error.message}`);
  logError('main', 'Uncaught exception:', error);
  dialog.showErrorBox('Error', `An unexpected error occurred:\n${error.message}`);
  app.exit(1);
});

// Handle unhandled promise rejections
process.on('unhandledRejection', (reason) => {
  writeStartupLog(`Unhandled rejection: ${reason}`);
  logError('main', 'Unhandled promise rejection:', reason);
});
