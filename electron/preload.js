// Preload script for security
// This runs in a context that has access to both Node.js and the web page
// Use this if you need to expose specific Node functionality to the renderer

const { contextBridge } = require('electron');

// Example: Expose safe APIs to renderer
// contextBridge.exposeInMainWorld('myAPI', {
//   doSomething: () => { /* ... */ }
// });
