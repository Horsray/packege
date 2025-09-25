; ===========================
; Photoshop 插件安装器模板（由 Electron 工具自动填充占位符）
; 保存为: installer.nsi
; 由外部脚本在编译前替换所有 __PLACEHOLDER__ 字样
; 编译: makensis installer.nsi
; ===========================

Unicode True
RequestExecutionLevel admin

!include "MUI2.nsh"
!include "LogicLib.nsh"
!include "nsDialogs.nsh"

; ---------- 基本信息 ----------
!define APP_NAME        "__APP_NAME__"
!define APP_PUBLISHER   "__APP_PUBLISHER__"
!define APP_VERSION     "__APP_VERSION__"
!define APP_VERSION_4   "__APP_VERSION_4__"
!define APP_DIRNAME     "__APP_DIRNAME__"  ; 安装到 Plug-ins 下的目录名
!define APP_NAME_FILE   "__APP_NAME_FILE__"
!define OUT_FILENAME    "${APP_NAME_FILE}_${APP_VERSION}.exe"
!define INSTALLER_ICON "__INSTALLER_ICON__"

!if "${INSTALLER_ICON}" != ""
  !define MUI_ICON "${INSTALLER_ICON}"
  !define MUI_UNICON "${INSTALLER_ICON}"
!endif

Name        "${APP_NAME}"
OutFile     "${OUT_FILENAME}"
!if "${INSTALLER_ICON}" != ""
Icon "${INSTALLER_ICON}"
UninstallIcon "${INSTALLER_ICON}"
!endif
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
Var PSCount
Var PSFoundPath
Var PSFoundNormalized
Var PSTrimLen
Var PSTrimChar

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
    StrCpy $PSPATH "$_tmp"

ParentLoop:
    StrLen $0 $PSPATH
    IntCmp $0 0 done
    StrCpy $1 $PSPATH 1 -1
    StrCmp $1 "\\" ParentFound 0
    StrCmp $1 "/" ParentFound 0
    StrCpy $PSPATH $PSPATH -1
    Goto ParentLoop

ParentFound:
    StrCpy $PSPATH $PSPATH -1

ParentTrimLoop:
    StrLen $0 $PSPATH
    IntCmp $0 0 done
    StrCpy $1 $PSPATH 1 -1
    StrCmp $1 "\\" ParentTrimDrop 0
    StrCmp $1 "/" ParentTrimDrop 0
    Goto ParentDone

ParentTrimDrop:
    StrCpy $PSPATH $PSPATH -1
    Goto ParentTrimLoop

ParentDone:
    StrCmp $PSPATH "" done
    StrCpy $_found "1"

done:
FunctionEnd

; 将找到的 Photoshop 目录入栈并计数
Function StoreFoundPath
  Pop $PSFoundPath
  Push $0
  Push $1

  StrCpy $PSFoundNormalized $PSFoundPath

TrimLoop:
  StrLen $PSTrimLen $PSFoundNormalized
  IntCmp $PSTrimLen 0 TrimDone
  StrCpy $PSTrimChar $PSFoundNormalized 1 -1
  StrCmp $PSTrimChar "\\" TrimDrop 0
  StrCmp $PSTrimChar "/" TrimDrop 0
  Goto TrimDone

TrimDrop:
  StrCpy $PSFoundNormalized $PSFoundNormalized -1
  Goto TrimLoop

TrimDone:
  Pop $1
  Pop $0
  StrCmp $PSFoundNormalized "" Restore

  Push $PSFoundNormalized
  IntOp $PSCount $PSCount + 1

Restore:
  StrCpy $_found ""
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
; 自动检测所有 Photoshop，并允许用户补充
Function FindPhotoshop
  StrCpy $PSPATH ""
  StrCpy $_found  ""
  StrCpy $_tmp    ""
  StrCpy $PSCount 0

  ; ===== 64-bit 视图 =====
  SetRegView 64

  StrCpy $0 0
Find_HKLM64_Loop:
  ClearErrors
  EnumRegKey $1 HKLM "SOFTWARE\Adobe\Photoshop" $0
  IfErrors Find_HKCU64_Start
  ReadRegStr $_tmp HKLM "SOFTWARE\Adobe\Photoshop\$1\ApplicationPath" ""
  Call NormalizeFromTmp
  StrCmp $_found "1" 0 +4
    Push $PSPATH
    Call StoreFoundPath
  IntOp $0 $0 + 1
  Goto Find_HKLM64_Loop

Find_HKCU64_Start:
  StrCpy $0 0
Find_HKCU64_Loop:
  ClearErrors
  EnumRegKey $1 HKCU "SOFTWARE\Adobe\Photoshop" $0
  IfErrors Check_AppPaths64
  ReadRegStr $_tmp HKCU "SOFTWARE\Adobe\Photoshop\$1\ApplicationPath" ""
  Call NormalizeFromTmp
  StrCmp $_found "1" 0 +4
    Push $PSPATH
    Call StoreFoundPath
  IntOp $0 $0 + 1
  Goto Find_HKCU64_Loop

Check_AppPaths64:
  ReadRegStr $_tmp HKLM "SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\Photoshop.exe" ""
  Call NormalizeFromTmp
  StrCmp $_found "1" 0 +4
    Push $PSPATH
    Call StoreFoundPath

  ReadRegStr $_tmp HKCU "SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\Photoshop.exe" ""
  Call NormalizeFromTmp
  StrCmp $_found "1" 0 +4
    Push $PSPATH
    Call StoreFoundPath

  ; ===== 32-bit 视图（兜底）=====
  SetRegView 32

  StrCpy $0 0
Find_HKLM32_Loop:
  ClearErrors
  EnumRegKey $1 HKLM "SOFTWARE\Adobe\Photoshop" $0
  IfErrors Find_HKCU32_Start
  ReadRegStr $_tmp HKLM "SOFTWARE\Adobe\Photoshop\$1\ApplicationPath" ""
  Call NormalizeFromTmp
  StrCmp $_found "1" 0 +4
    Push $PSPATH
    Call StoreFoundPath
  IntOp $0 $0 + 1
  Goto Find_HKLM32_Loop

Find_HKCU32_Start:
  StrCpy $0 0
Find_HKCU32_Loop:
  ClearErrors
  EnumRegKey $1 HKCU "SOFTWARE\Adobe\Photoshop" $0
  IfErrors Check_AppPaths32
  ReadRegStr $_tmp HKCU "SOFTWARE\Adobe\Photoshop\$1\ApplicationPath" ""
  Call NormalizeFromTmp
  StrCmp $_found "1" 0 +4
    Push $PSPATH
    Call StoreFoundPath
  IntOp $0 $0 + 1
  Goto Find_HKCU32_Loop

Check_AppPaths32:
  ReadRegStr $_tmp HKLM "SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\Photoshop.exe" ""
  Call NormalizeFromTmp
  StrCmp $_found "1" 0 +4
    Push $PSPATH
    Call StoreFoundPath

  ReadRegStr $_tmp HKCU "SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\Photoshop.exe" ""
  Call NormalizeFromTmp
  StrCmp $_found "1" 0 +4
    Push $PSPATH
    Call StoreFoundPath

  ; ===== 手动选择（必要或追加）=====
  StrCmp $PSCount 0 ManualRequired ManualOptional

ManualRequired:
  MessageBox MB_ICONEXCLAMATION|MB_OKCANCEL "未能自动找到 Photoshop 安装目录。是否手动选择？$\r$\n（请选择包含 Photoshop.exe 的目录）" IDCANCEL ManualAbort
  Goto ManualSelect

ManualOptional:
  MessageBox MB_ICONQUESTION|MB_YESNO "已自动检测到 $PSCount 个 Photoshop 安装目录。是否额外手动添加其他目录？" IDNO FinishDetection

ManualSelect:
  nsDialogs::SelectFolderDialog "选择 Photoshop 安装目录（包含 Photoshop.exe 的那一层）" "$PROGRAMFILES\Adobe"
  Pop $0
  StrCmp "$0" "" ManualCancel
  IfFileExists "$0\Photoshop.exe" 0 ManualInvalid
  Push $0
  Call StoreFoundPath
  MessageBox MB_ICONQUESTION|MB_YESNO "是否继续添加其他 Photoshop 安装目录？" IDYES ManualSelect
  Goto FinishDetection

ManualInvalid:
  MessageBox MB_ICONSTOP "选择的目录下未找到 Photoshop.exe，请重试。"
  Goto ManualSelect

ManualCancel:
  StrCmp $PSCount 0 ManualAbort FinishDetection

ManualAbort:
  StrCpy $PSCount 0

FinishDetection:
  Push $PSCount
FunctionEnd




; ---------- 安装前置 ----------
; 不在 .onInit 里做任何检测或弹窗，避免启动即闪退
Function .onInit
FunctionEnd


Function InstallIntoCurrent
  Push $0
  Push $1
  CreateDirectory "$INSTDIR"
  SetOutPath "$INSTDIR"
  File /r "__PAYLOAD_GLOB__"
  WriteUninstaller "$INSTDIR\Uninstall.exe"
  Pop $1
  Pop $0
FunctionEnd


; ---------- 安装 ----------
Section "Install"
  SetShellVarContext all

  Call FindPhotoshop
  Pop $PSCount
  StrCmp "$PSCount" "0" _abort_install

  StrCpy $0 $PSCount

InstallLoop:
  IntCmp $0 0 InstallDone
  Pop $PSPATH
  DetailPrint "使用 Photoshop 目录：$PSPATH"
  StrCpy $INSTDIR "$PSPATH\Plug-ins\${APP_DIRNAME}"
  Call InstallIntoCurrent
  DetailPrint "已安装到：$INSTDIR"
  IntOp $0 $0 - 1
  Goto InstallLoop

InstallDone:
  DetailPrint "所有检测到的 Photoshop 已完成安装。"
  Goto SectionEnd

_abort_install:
  MessageBox MB_ICONINFORMATION "已取消安装。"
  Abort

SectionEnd:
SectionEnd


; ---------- 卸载 ----------
Section "Uninstall"
  SetShellVarContext all
  StrCpy $INSTDIR $EXEDIR
  RMDir /r "$INSTDIR"
  DetailPrint "已卸载：$INSTDIR"
SectionEnd
