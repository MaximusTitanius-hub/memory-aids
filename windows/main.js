// Electron main process: window, storage, PDF reading and AI calls.
const { app, BrowserWindow, ipcMain, dialog, safeStorage, shell } = require('electron');
const path = require('path');
const fs = require('fs');
const gen = require('./generator');
const { TECHNIQUES, STARTER_PACK } = require('./shared/techniques');

const dataDir = () => app.getPath('userData');
const setsFile = () => path.join(dataDir(), 'sets.json');
const settingsFile = () => path.join(dataDir(), 'settings.json');
const keyFile = () => path.join(dataDir(), 'claude-key.bin');

const DEFAULT_SETTINGS = { engine: 'auto', ollamaModel: 'gemma3:4b' };

function readJSON(file, fallback) {
  try { return JSON.parse(fs.readFileSync(file, 'utf8')); } catch { return fallback; }
}
function writeJSON(file, value) {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  const tmp = `${file}.tmp`;
  fs.writeFileSync(tmp, JSON.stringify(value));
  fs.renameSync(tmp, file);
}

function loadKey() {
  try {
    const raw = fs.readFileSync(keyFile());
    return safeStorage.isEncryptionAvailable() ? safeStorage.decryptString(raw) : raw.toString('utf8');
  } catch { return ''; }
}
function saveKey(key) {
  const trimmed = (key || '').trim();
  if (!trimmed) { try { fs.unlinkSync(keyFile()); } catch { /* none saved */ } return; }
  fs.mkdirSync(dataDir(), { recursive: true });
  const data = safeStorage.isEncryptionAvailable() ? safeStorage.encryptString(trimmed) : Buffer.from(trimmed, 'utf8');
  fs.writeFileSync(keyFile(), data);
}

function settings() { return { ...DEFAULT_SETTINGS, ...readJSON(settingsFile(), {}) }; }

function resolveEngine(engine) {
  if (engine === 'auto') return loadKey() ? 'claude' : 'ollama';
  return engine;
}

async function pdfText(buffer) {
  const pdfjs = await import('pdfjs-dist/legacy/build/pdf.mjs');
  const doc = await pdfjs.getDocument({ data: new Uint8Array(buffer), useSystemFonts: true, isEvalSupported: false }).promise;
  const pages = [];
  for (let i = 1; i <= doc.numPages; i += 1) {
    const page = await doc.getPage(i);
    const content = await page.getTextContent();
    let line = '';
    let lastY = null;
    const out = [];
    for (const item of content.items) {
      if (!('str' in item)) continue;
      const y = item.transform[5];
      if (lastY !== null && Math.abs(y - lastY) > 2) { out.push(line); line = ''; }
      line += item.str;
      if (item.hasEOL) { out.push(line); line = ''; }
      lastY = y;
    }
    if (line) out.push(line);
    pages.push(out.join('\n'));
  }
  return pages.join('\n\n').replace(/\n{3,}/g, '\n\n').trim();
}

async function importFile(filePath) {
  const buffer = fs.readFileSync(filePath);
  const name = path.basename(filePath);
  if (filePath.toLowerCase().endsWith('.pdf')) {
    const text = await pdfText(buffer);
    return { name, text, pdfBase64: buffer.toString('base64') };
  }
  return { name, text: buffer.toString('utf8'), pdfBase64: null };
}

function createWindow() {
  const win = new BrowserWindow({
    width: 1280, height: 860, minWidth: 980, minHeight: 640,
    title: 'Memory Aids',
    backgroundColor: '#f6f5fb',
    icon: path.join(__dirname, 'assets', 'icon.png'),
    autoHideMenuBar: true,
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      sandbox: true,
      nodeIntegration: false,
    },
  });
  win.loadFile(path.join(__dirname, 'renderer', 'index.html'));
  // Links open in the normal web browser, never inside the app.
  win.webContents.setWindowOpenHandler(({ url }) => {
    if (url.startsWith('https://')) shell.openExternal(url);
    return { action: 'deny' };
  });
  win.webContents.on('will-navigate', (e, url) => {
    if (url !== win.webContents.getURL()) e.preventDefault();
  });
}

ipcMain.handle('techniques', () => ({ techniques: TECHNIQUES, starterPack: STARTER_PACK }));
ipcMain.handle('sets:load', () => readJSON(setsFile(), []));
ipcMain.handle('sets:save', (_e, sets) => { writeJSON(setsFile(), sets); return true; });
ipcMain.handle('settings:get', () => ({ ...settings(), hasKey: Boolean(loadKey()) }));
ipcMain.handle('settings:set', (_e, patch) => {
  const next = { ...settings(), ...patch };
  delete next.hasKey;
  writeJSON(settingsFile(), next);
  return { ...next, hasKey: Boolean(loadKey()) };
});
ipcMain.handle('key:save', (_e, key) => { saveKey(key); return Boolean(loadKey()); });
ipcMain.handle('engine:resolve', () => resolveEngine(settings().engine));
ipcMain.handle('ollama:status', () => gen.ollamaStatus(settings().ollamaModel));
ipcMain.handle('ollama:pull', async (e) => {
  const { ollamaModel } = settings();
  await gen.ollamaPull(ollamaModel, (pct, status) => e.sender.send('ollama:pull-progress', { pct, status }));
  return true;
});
ipcMain.handle('file:open', async (e) => {
  const win = BrowserWindow.fromWebContents(e.sender);
  const res = await dialog.showOpenDialog(win, {
    title: 'Choose your notes',
    properties: ['openFile'],
    filters: [{ name: 'PDF or text', extensions: ['pdf', 'txt', 'md'] }],
  });
  if (res.canceled || !res.filePaths[0]) return null;
  return importFile(res.filePaths[0]);
});
ipcMain.handle('file:import', (_e, filePath) => importFile(filePath));
ipcMain.handle('generate', async (e, { material, pdfBase64, techniqueIds }) => {
  const s = settings();
  const engine = resolveEngine(s.engine);
  const onProgress = (pct, status) => e.sender.send('generate:progress', { pct, status });
  if (engine === 'claude') {
    const apiKey = loadKey();
    if (!apiKey) throw new Error('Add your Claude API key in Settings first, or switch to the free AI.');
    return gen.runClaude({ apiKey, material, pdfBase64, techniqueIds, onProgress });
  }
  return gen.runOllama({ model: s.ollamaModel, material, techniqueIds, onProgress });
});

app.whenReady().then(() => {
  createWindow();
  app.on('activate', () => { if (BrowserWindow.getAllWindows().length === 0) createWindow(); });
});
app.on('window-all-closed', () => { if (process.platform !== 'darwin') app.quit(); });
