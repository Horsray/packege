// src/main.js — minimal stable
import { app, BrowserWindow, dialog, ipcMain } from 'electron';
import path from 'path';
import { fileURLToPath } from 'url';
import fs from 'fs';
import fse from 'fs-extra';
import { spawn } from 'child_process';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

let win;
let buildRunning = false;

// ========== Window ==========
function createWindow() {
  win = new BrowserWindow({
    width: 900,
    height: 640,
    webPreferences: {
      // 只用这一条，确保和 src/preload.cjs 匹配
      preload: path.join(__dirname, 'preload.cjs'),
      contextIsolation: true,
      sandbox: false,
      nodeIntegration: false,
    },
  });

  win.loadFile(path.join(__dirname, 'renderer', 'index.html'));
  // win.webContents.openDevTools({ mode: 'detach' });
}

app.whenReady().then(createWindow);
app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') app.quit();
});
app.on('activate', () => {
  if (BrowserWindow.getAllWindows().length === 0) createWindow();
});

// ========== helpers ==========
function log(type, msg) {
  if (win && !win.isDestroyed()) {
    win.webContents.send('log', { type, msg });
  }
}
function execp(cmd, args, opts = {}) {
  return new Promise((resolve, reject) => {
    const p = spawn(cmd, args, { shell: false, ...opts });
    p.stdout.on('data', d => log('info', d.toString()));
    p.stderr.on('data', d => log('warn', d.toString()));
    p.on('close', c => (c === 0 ? resolve() : reject(new Error(cmd + ' exit ' + c))));
  });
}
function sanitize(name) {
  return String(name).replace(/[\\/:*?"<>|]/g, '_').trim();
}

function resolveOutFileName(requested, fallback) {
  const sanitized = sanitize(requested || '');
  const baseWithoutExt = sanitized.replace(/\.exe$/i, '').trim();
  const meaningful = baseWithoutExt.replace(/[_\.-]/g, '').trim();
  let finalName = sanitized && baseWithoutExt && meaningful ? sanitized : fallback;
  if (!/\.exe$/i.test(finalName)) {
    finalName += '.exe';
  }
  return finalName;
}

// ========== 目录选择 ==========
ipcMain.handle('select-folder', async (_evt, defaultPathFromUI) => {
  const res = await dialog.showOpenDialog({
    title: '选择插件母文件夹',
    buttonLabel: '选择这个文件夹',
    defaultPath: defaultPathFromUI || undefined,
    properties: ['openDirectory', 'createDirectory', 'dontAddToRecent', 'treatPackageAsDirectory'],
  });
  if (res.canceled || !res.filePaths?.[0]) return null;
  return res.filePaths[0];
});

// ========== mac: pkgbuild ==========
async function buildMac({ pluginDir, name, version, outDir }) {
  if (process.platform !== 'darwin') throw new Error('只能在 macOS 上生成 .pkg');

  const workRoot = path.join(app.getPath('temp'), 'pkgwork-' + Date.now());
  const payloadRoot = path.join(workRoot, 'root');
  const scriptsDir = path.join(workRoot, 'scripts');
  const payloadAppDir = path.join(payloadRoot, name);

  await fse.ensureDir(payloadAppDir);
  await fse.copy(pluginDir, payloadAppDir, { dereference: true });

  await fse.ensureDir(scriptsDir);
  const postSrc = path.join(__dirname, '..', 'scripts', 'macos_postinstall.sh');
  const postDst = path.join(scriptsDir, 'postinstall');
  let postContent = await fs.promises.readFile(postSrc, 'utf-8');
  postContent = postContent.replace(/__APP_NAME__/g, name);
  await fs.promises.writeFile(postDst, postContent, 'utf-8');
  await fs.promises.chmod(postDst, 0o755);

  await fse.ensureDir(outDir);
  const bundleId = 'cn.hueying.psplugin.' + sanitize(String(name).toLowerCase());
  const component = path.join(outDir, `${name}.pkg`);
  const installLocation = `/Library/Application Support/${name}-payload`;

  log('info', 'pkgbuild...');
  await execp('pkgbuild', [
    '--root', payloadRoot,
    '--identifier', bundleId,
    '--version', version,
    '--scripts', scriptsDir,
    '--install-location', installLocation,
    component,
  ]);

  const finalPkg = path.join(outDir, `${name}-${version}.pkg`);
  await fse.copy(component, finalPkg);
  try { await fs.promises.unlink(component); } catch {}
  log('success', 'macOS 安装包已生成：' + finalPkg);
}

// ========== win: NSIS ==========
async function buildWin({ pluginDir, name, version, outDir, installerFileName }) {
  const appNameDisplay = String(name); // 用于 Name/显示（可中文）
  const appNameFile = String(name)
    .replace(/[\\/:*?"<>|]/g, '_')
    .replace(/[^\x20-\x7E]/g, '_'); // ASCII-only
  const pluginBaseName = path.basename(path.resolve(pluginDir));
  const appDirName = (pluginBaseName && pluginBaseName !== '.'
    ? pluginBaseName
    : appNameDisplay
  ) || appNameDisplay || appNameFile;
  const numericParts = String(version).match(/\d+/g) || [];
  const productVersion = [...numericParts, '0', '0', '0', '0']
    .slice(0, 4)
    .map((part) => {
      const num = Number.parseInt(part, 10);
      if (!Number.isFinite(num) || num < 0) return '0';
      return String(Math.min(num, 65535));
    })
    .join('.');
  const appPublisher = appNameDisplay.trim() || appNameFile;
  const nsisEscape = (s) => String(s).replace(/\\/g, '\\\\').replace(/"/g, '\\"');

  const nsisT = await fs.promises.readFile(
    path.join(__dirname, '..', 'scripts', 'nsis_template.nsi'),
    'utf-8'
  );
  const work = path.join(app.getPath('temp'), 'nsis-' + Date.now());
  await fse.ensureDir(work);
  const srcCopy = path.join(work, 'payload');
  await fse.emptyDir(srcCopy);
  await fse.copy(pluginDir, srcCopy, { dereference: true });
  const payloadGlob = path.join(srcCopy, '*.*');
  let nsi = nsisT
    // 这些占位符在模板中已位于引号或 define 环境中，这里不要再额外加引号！
    .replace(/__APP_NAME_FILE__/g, appNameFile)                 // ASCII 安全
    .replace(/__APP_VERSION__/g, version)                       // 纯字面量
    .replace(/__APP_VERSION_4__/g, productVersion)              // VIProductVersion
    .replace(/__APP_NAME__/g, nsisEscape(appNameDisplay))       // 模板里已 "Name "__APP_NAME__""
    .replace(/__APP_NAME_WIN__/g, nsisEscape(appNameDisplay))   // 若模板使用，通常也在引号内
    .replace(/__APP_PUBLISHER__/g, nsisEscape(appPublisher))
    .replace(/__APP_DIRNAME__/g, nsisEscape(appDirName))
    .replace(/__PAYLOAD_GLOB__/g, nsisEscape(payloadGlob));          // 模板里是 !define PAYLOAD_DIR __PAYLOAD_DIR__
  console.log("Generated NSIS content:\n", nsi);  // 打印替换后的 nsi 内容

  const defaultOutName = `${appNameFile}-${version}.exe`;
  const outName = resolveOutFileName(installerFileName, defaultOutName);
  nsi = nsi.replace(/(^|\n)\s*OutFile\s+"[^"]+"\s*/i, `\nOutFile "dist/${outName}"\n`);

  const nsiPath = path.join(work, 'installer.nsi');
  await fs.promises.writeFile(nsiPath, nsi, 'utf-8');

  await fse.ensureDir(path.join(work, 'dist'));
  await fse.ensureDir(outDir);

  const makensis = process.platform === 'win32' ? 'makensis.exe' : 'makensis';
  log('info', 'makensis...');
  await execp(makensis, [nsiPath], { cwd: work });

  const built = path.join(work, 'dist', outName);
  const final = path.join(outDir, outName);
  await fse.copy(built, final, { overwrite: true });
  log('success', 'Windows 安装包已生成：' + final);
}

// ========== 打包入口 ==========
ipcMain.handle('build', async (_evt, { platform, pluginDir, name, version, installerFileName }) => {
  const outDir = path.join(path.dirname(pluginDir), 'dist');
  try {
    if (buildRunning) return { ok: false, error: '正在打包中，请稍候完成后再试' };
    buildRunning = true;

    const displayName = (name && String(name).trim()) || path.basename(pluginDir);
    const pkgVersion = (version && String(version).trim()) || '1.0.0';

    await fse.ensureDir(outDir);
    if (platform === 'mac' || platform === 'both') {
      await buildMac({ pluginDir, name: displayName, version: pkgVersion, outDir });
    }
    if (platform === 'win' || platform === 'both') {
      await buildWin({ pluginDir, name: displayName, version: pkgVersion, outDir, installerFileName });
    }

    return { ok: true, outDir };
  } catch (e) {
    log('error', e?.message || String(e));
    return { ok: false, error: e?.message || String(e) };
  } finally {
    buildRunning = false;
  }
});
