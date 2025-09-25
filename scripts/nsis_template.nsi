; ===========================
; Photoshop 插件安装器模板（由 Electron 工具自动填充占位符）
; 保存为: installer.nsi
; 由外部脚本在编译前替换所有 __PLACEHOLDER__ 字样
; 编译: makensis installer.nsi
; ===========================

Unicode True
RequestExecutionLevel admin

!include "MUI2.nsh"
!include "FileFunc.nsh"
!include "nsDialogs.nsh"

; ---------- 基本信息 ----------
!define APP_NAME        "__APP_NAME__"
!define APP_PUBLISHER   "__APP_PUBLISHER__"
!define APP_VERSION     "__APP_VERSION__"
!define APP_VERSION_4   "__APP_VERSION_4__"
!define APP_DIRNAME     "__APP_DIRNAME__"  ; 安装到 Plug-ins 下的目录名
!define APP_NAME_FILE   "__APP_NAME_FILE__"
!define OUT_FILENAME    "${APP_NAME_FILE}_${APP_VERSION}.exe"

Name        "${APP_NAME}"
OutFile     "${OUT_FILENAME}"
BrandingText "Installer • ${APP_PUBLISHER}"

VIProductVersion "${APP_VERSION_4}"
VIAddVersionKey "ProductName" "${APP_NAME}"
VIAddVersionKey "FileDescription" "${APP_NAME}"
VIAddVersionKey "CompanyName" "${APP_PUBLISHER}"
VIAddVersionKey "FileVersion" "${APP_VERSION}"
VIAddVersionKey "ProductVersion" "${APP_VERSION}"

; InstallDir 只是占位；真正安装路径用 $PSPATH 拼出来
InstallDir  "$PROGRAMFILES\${APP_DIRNAME}"

; ---------- UI 页面 ----------
!define MUI_ABORTWARNING
!insertmacro MUI_PAGE_WELCOME
Page custom PreInstallConfirm
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH
!insertmacro MUI_LANGUAGE "SimpChinese"

; ---------- 变量 ----------
Var PSPATH
Var _found
Var _tmp

; ---------- 小宏：尝试读取注册表字符串 ----------
!macro TRY_READ REGROOT SUBKEY VALUENAME
  ClearErrors
  ReadRegStr $_tmp ${REGROOT} "${SUBKEY}" "${VALUENAME}"
  IfErrors +2
    StrCmp $_tmp "" +1 0
  StrCmp $_tmp "" +6
    ; 读到非空值：可能是目录或 EXE 完整路径
    StrCpy $PSPATH "$_tmp"
    StrCpy $_found "1"
    Return
!macroend
; 把 $_tmp 规范化为 $PSPATH（目录）：
; - $_tmp 是目录 => 直接命中
; - $_tmp 是文件（exe 全路径）=> 取其父目录命中
; - $_tmp 为空或不存在 => 不改 $_found
Function NormalizeFromTmp
  StrCmp $_tmp "" done

  ; 是目录？
  IfFileExists "$_tmp\*.*" 0 +3
    StrCpy $PSPATH "$_tmp"
    StrCpy $_found "1"
    Goto done

  ; 是文件？
  IfFileExists "$_tmp" 0 done
    ${GetParent} "$_tmp" $PSPATH
    StrCmp $PSPATH "" 0 +2
    StrCpy $_found "1"

done:
FunctionEnd
Function PreInstallConfirm
  ; 一个极简的 nsDialogs 页面，只有提示文本与“下一步”按钮
  nsDialogs::Create 1018
  Pop $0
  ${If} $0 == error
    Abort
  ${EndIf}

  ${NSD_CreateLabel} 0 0 100% 24u "将安装到已选择的 Photoshop。请确认后点击“下一步”开始安装。"
  Pop $1

  nsDialogs::Show
FunctionEnd

; ---------- 查找 Photoshop ----------
; 只做“自动检测”，不弹窗；手选放在 Section 里做
Function FindPhotoshop
  ; —— 只做自动检测，不弹窗；手选在 Section 里做 ——
  StrCpy $PSPATH ""
  StrCpy $_found  ""
  StrCpy $_tmp    ""

  ; ===== 64-bit 视图 =====
  SetRegView 64

  ; HKLM\SOFTWARE\Adobe\Photoshop\*\ApplicationPath  (默认值 "")
  StrCpy $0 0
Find_HKLM64_Loop:
  ClearErrors
  EnumRegKey $1 HKLM "SOFTWARE\Adobe\Photoshop" $0
  IfErrors Find_HKCU64_Start
  ReadRegStr $_tmp HKLM "SOFTWARE\Adobe\Photoshop\$1\ApplicationPath" ""
  Call NormalizeFromTmp
  StrCmp $_found "1" found_done 0
  IntOp $0 $0 + 1
  Goto Find_HKLM64_Loop

Find_HKCU64_Start:
  ; HKCU\SOFTWARE\Adobe\Photoshop\*\ApplicationPath  (默认值 "")
  StrCpy $0 0
Find_HKCU64_Loop:
  ClearErrors
  EnumRegKey $1 HKCU "SOFTWARE\Adobe\Photoshop" $0
  IfErrors Check_AppPaths64
  ReadRegStr $_tmp HKCU "SOFTWARE\Adobe\Photoshop\$1\ApplicationPath" ""
  Call NormalizeFromTmp
  StrCmp $_found "1" found_done 0
  IntOp $0 $0 + 1
  Goto Find_HKCU64_Loop

Check_AppPaths64:
  ; App Paths\Photoshop.exe（默认值可能是 EXE 全路径）
  ReadRegStr $_tmp HKLM "SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\Photoshop.exe" ""
  Call NormalizeFromTmp
  StrCmp $_found "1" found_done 0

  ReadRegStr $_tmp HKCU "SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\Photoshop.exe" ""
  Call NormalizeFromTmp
  StrCmp $_found "1" found_done 0

  ; ===== 32-bit 视图（兜底）=====
  SetRegView 32

  ; HKLM\SOFTWARE\Adobe\Photoshop\*\ApplicationPath  (默认值 "")
  StrCpy $0 0
Find_HKLM32_Loop:
  ClearErrors
  EnumRegKey $1 HKLM "SOFTWARE\Adobe\Photoshop" $0
  IfErrors Find_HKCU32_Start
  ReadRegStr $_tmp HKLM "SOFTWARE\Adobe\Photoshop\$1\ApplicationPath" ""
  Call NormalizeFromTmp
  StrCmp $_found "1" found_done 0
  IntOp $0 $0 + 1
  Goto Find_HKLM32_Loop

Find_HKCU32_Start:
  ; HKCU\SOFTWARE\Adobe\Photoshop\*\ApplicationPath  (默认值 "")
  StrCpy $0 0
Find_HKCU32_Loop:
  ClearErrors
  EnumRegKey $1 HKCU "SOFTWARE\Adobe\Photoshop" $0
  IfErrors Check_AppPaths32
  ReadRegStr $_tmp HKCU "SOFTWARE\Adobe\Photoshop\$1\ApplicationPath" ""
  Call NormalizeFromTmp
  StrCmp $_found "1" found_done 0
  IntOp $0 $0 + 1
  Goto Find_HKCU32_Loop

Check_AppPaths32:
  ReadRegStr $_tmp HKLM "SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\Photoshop.exe" ""
  Call NormalizeFromTmp
  StrCmp $_found "1" found_done 0

  ReadRegStr $_tmp HKCU "SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\Photoshop.exe" ""
  Call NormalizeFromTmp
  StrCmp $_found "1" found_done 0

  ; 没找到就让 Section 后续的“常见目录 + 手选”接力
  Goto done

found_done:
  ; 这里 $PSPATH 已是目录；若极端情况是 EXE 路径，NormalizeFromTmp 已取父目录
  ; 不做 UI，仅返回 $PSPATH 供 Section 使用
done:
FunctionEnd




; ---------- 安装前置 ----------
; 不在 .onInit 里做任何检测或弹窗，避免启动即闪退
Function .onInit
FunctionEnd


; ---------- 安装 ----------
Section "Install"
  SetShellVarContext all

  ; 进入安装阶段再检测（此时弹窗安全）
  Call FindPhotoshop

  ; 若仍未检测到，则提示手动选择；循环直到选对或取消
  StrCmp "$PSPATH" "" 0 +5
    MessageBox MB_ICONEXCLAMATION|MB_OKCANCEL "未能自动找到 Photoshop 安装目录。是否手动选择？$\r$\n（请选择包含 Photoshop.exe 的目录）" IDCANCEL _abort_install
    nsDialogs::SelectFolderDialog "选择 Photoshop 安装目录（包含 Photoshop.exe 的那一层）" "$PROGRAMFILES\Adobe"
    Pop $PSPATH
    StrCmp "$PSPATH" "" _abort_install
    IfFileExists "$PSPATH\Photoshop.exe" 0 _retry_select

  ; 到这里 $PSPATH 一定有效
  DetailPrint "使用 Photoshop 目录：$PSPATH"

  ; 安装到：<PS>\Plug-ins\${APP_DIRNAME}
  StrCpy $INSTDIR "$PSPATH\Plug-ins\${APP_DIRNAME}"
  CreateDirectory "$INSTDIR"
  SetOutPath "$INSTDIR"
  File /r "__PAYLOAD_GLOB__"

  ; 写入卸载器
  WriteUninstaller "$INSTDIR\Uninstall.exe"

  DetailPrint "已安装到：$INSTDIR"
  Goto _end

_retry_select:
  MessageBox MB_ICONSTOP "选择的目录下未找到 Photoshop.exe，请重试。"
  Goto -6  ; 回到 MessageBox 询问是否手选

_abort_install:
  MessageBox MB_ICONINFORMATION "已取消安装。"
  Abort

_end:
SectionEnd


; ---------- 卸载 ----------
Section "Uninstall"
  SetShellVarContext all
  RMDir /r "$INSTDIR"
  DetailPrint "已卸载：$INSTDIR"
SectionEnd
