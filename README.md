
# Dual Installer Builder (Electron)

可视化工具：选择你的插件母文件夹，输入名称与版本号，一键生成：
- Windows 安装包（NSIS .exe）
- macOS 安装包（pkgbuild/productbuild .pkg）

## 依赖
- Node.js 18+
- macOS 生成 .pkg：需要 Xcode Command Line Tools（内置 pkgbuild/productbuild）
- 生成 .exe：需要 NSIS (makensis)
  - macOS：`brew install makensis`
  - Windows：安装 NSIS，并将 makensis.exe 添加到 PATH

## 运行
```
npm install
npm start
```
