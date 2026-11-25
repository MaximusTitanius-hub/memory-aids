// Safe bridge between the window (renderer) and the main process.
const { contextBridge, ipcRenderer, webUtils } = require('electron');

function strip(err) {
  // Electron prefixes errors from handlers; keep only the readable part.
  const msg = (err && err.message) || String(err);
  return msg.replace(/^Error invoking remote method '[^']+': (Error: )?/, '');
}
async function call(channel, ...args) {
  try { return await ipcRenderer.invoke(channel, ...args); } catch (err) { throw new Error(strip(err)); }
}

contextBridge.exposeInMainWorld('api', {
  techniques: () => call('techniques'),
  loadSets: () => call('sets:load'),
  saveSets: (sets) => call('sets:save', sets),
  getSettings: () => call('settings:get'),
  setSettings: (patch) => call('settings:set', patch),
  saveKey: (key) => call('key:save', key),
  resolveEngine: () => call('engine:resolve'),
  ollamaStatus: () => call('ollama:status'),
  ollamaPull: () => call('ollama:pull'),
  openFile: () => call('file:open'),
  importDropped: (file) => call('file:import', webUtils.getPathForFile(file)),
  generate: (req) => call('generate', req),
  onProgress: (fn) => {
    const listener = (_e, data) => fn(data);
    ipcRenderer.on('generate:progress', listener);
    return () => ipcRenderer.removeListener('generate:progress', listener);
  },
  onPullProgress: (fn) => {
    const listener = (_e, data) => fn(data);
    ipcRenderer.on('ollama:pull-progress', listener);
    return () => ipcRenderer.removeListener('ollama:pull-progress', listener);
  },
});
