// src/preload.cjs — CommonJS, expose window.api exactly once
const { contextBridge, ipcRenderer } = require('electron');
const path = require('path');

const api = {
  // 目录选择（系统面板）
  selectFolder: (def) => ipcRenderer.invoke('select-folder', def),
  // 打包
  build: (payload) => ipcRenderer.invoke('build', payload),
  // 日志
  onLog: (fn) => ipcRenderer.on('log', (_e, d) => fn(d)),
  // 路径工具（UI 里会用到）
  pathDirname:  (p = '') => path.dirname(p),
  pathBasename: (p = '') => path.basename(p),
};

process.once('loaded', () => {
  console.log('[preload] loaded');
});

try {
  if (!window.api) {
    contextBridge.exposeInMainWorld('api', api);
  }
  console.log('[preload] exposed');
} catch (e) {
  console.error('[preload] expose error:', e);
}