const { contextBridge, ipcRenderer } = require('electron');

// Expose protected methods that allow the renderer process to use
// the ipcRenderer without exposing the entire object
contextBridge.exposeInMainWorld('electronAPI', {
  installGlobalFix: (appId, goldbergOptions) => ipcRenderer.invoke('install-globalfix', appId, goldbergOptions),
  fetchSteamApps: () => ipcRenderer.invoke('fetch-steam-apps')
});
