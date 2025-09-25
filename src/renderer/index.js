// src/renderer/index.js
document.addEventListener('DOMContentLoaded', () => {
  console.log('[renderer] DOM ready');

  const $ = s => document.querySelector(s);
  const log = (t,m)=>{
    const l=document.createElement('div');
    l.className=t; l.textContent=m;
    $('#log').appendChild(l);
    $('#log').scrollTop = $('#log').scrollHeight;
  };

  if (!window.api) {
    console.error('[renderer] window.api 未注入，检查 preload 路径/参数');
    alert('预加载未注入（window.api 不存在）。请按步骤修改 main.js 的 webPreferences。');
    return;
  }
  window.api.onLog(d=>log(d.type,d.msg));

  const folderInput = $('#folder');
  const nameInput   = $('#name');
  const versionInput= $('#version');
  const installerNameInput = $('#installerName');
  const pickBtn     = $('#pick');
  const dirPicker   = $('#dirPicker'); // 隐藏的目录选择器

  const invalidFileChars = /[\\/:*?"<>|]/g;
  let installerNameManual = false;
  let ignoreInstallerInput = false;

  function fillNameIfEmpty(dirPath){
    if (!nameInput.value) {
      nameInput.value = window.api.pathBasename(dirPath) || '插件';
      ensureInstallerName();
    }
  }

  function sanitizePart(text, fallback) {
    const replaced = String(text || '')
      .replace(invalidFileChars, '_')
      .replace(/\s+/g, '_')
      .replace(/_+/g, '_')
      .replace(/^_+|_+$/g, '');
    const meaningful = replaced.replace(/[_\.-]/g, '').trim();
    return meaningful ? replaced : fallback;
  }

  function makeDefaultInstallerName() {
    const folderName = window.api.pathBasename(folderInput.value.trim()) || '';
    const base = sanitizePart(nameInput.value.trim() || folderName, 'Plugin');
    const version = sanitizePart(versionInput.value.trim(), '1.0.0');
    return `Setup-${base}-${version}.exe`;
  }

  function applyDefaultInstallerName() {
    if (!installerNameInput) return;
    ignoreInstallerInput = true;
    installerNameInput.value = makeDefaultInstallerName();
    ignoreInstallerInput = false;
    installerNameManual = false;
  }

  function ensureInstallerName() {
    if (!installerNameInput) return;
    if (!installerNameManual) {
      applyDefaultInstallerName();
    }
  }

  installerNameInput?.addEventListener('input', () => {
    if (ignoreInstallerInput) return;
    installerNameManual = installerNameInput.value.trim().length > 0;
  });

  nameInput?.addEventListener('input', () => {
    ensureInstallerName();
  });

  versionInput?.addEventListener('input', () => {
    ensureInstallerName();
  });

  // 统一设置目录
  function setFolder(dirPath){
    if (!dirPath) return;
    folderInput.value = dirPath;
    if (!nameInput.value) nameInput.value = window.api.pathBasename(dirPath) || '插件';
    ensureInstallerName();
    log('success', `已选择：${dirPath}`);
  }

  // A. 原生对话框（首选）
  pickBtn?.addEventListener('click', async () => {
    try {
      const dir = await window.api.selectFolder();
      if (dir) setFolder(dir);
      else log('warn', '未选择任何文件夹');  // 用户手动点了“取消”才会看到这句
    } catch (e) {
      log('error', '系统选择面板失败，改用兜底目录选择：' + (e?.message || e));
      dirPicker.click(); // 兜底：隐藏的 <input webkitdirectory>
    }
  });

  // B. 兜底 <input type="file" webkitdirectory>
  dirPicker?.addEventListener('change', (e) => {
    const files = Array.from(e.target.files || []);
    if (!files.length) return;
    const dir = window.api.pathDirname(files[0].path);
    setFolder(dir);
    e.target.value = '';
  });

  // C. 拖拽文件夹/文件到窗口（文件则取所在目录）
  ['dragenter','dragover','dragleave','drop'].forEach(evt=>{
    document.addEventListener(evt, (ev)=>{ ev.preventDefault(); ev.stopPropagation(); }, false);
  });
  document.addEventListener('drop', (e)=>{
    const items = e.dataTransfer?.files || [];
    if (!items.length) return;
    const first = items[0];
    const p = first.path;
    const dir = first.type ? window.api.pathDirname(p) : p; // 文件→父目录；目录→自身
    setFolder(dir);
  }, false);

  // 打包
  async function build(platform){
    const pluginDir = folderInput.value.trim();
    const name = nameInput.value.trim();
    const version = versionInput.value.trim();
    const installerFileName = installerNameInput?.value.trim();
    if (!pluginDir) return log('error','请选择插件文件夹（点击“选择”或拖拽到窗口）');
    if (!name)      return log('error','请填写显示名称');
    if (!version)   return log('error','请填写版本号');
    if (!installerNameManual) ensureInstallerName();
    const res = await window.api.build({ platform, pluginDir, name, version, installerFileName });
    if (res.ok) log('success','完成，输出目录：'+res.outDir);
  }
  $('#mac') ?.addEventListener('click', ()=>build('mac'));
  $('#win') ?.addEventListener('click', ()=>build('win'));
  $('#both')?.addEventListener('click', ()=>build('both'));
  ensureInstallerName();
});
