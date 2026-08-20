; +-------------------------------------------------------------------------
;
;   taskmgr-rs - Windows Inno Setup 安装包
;
;   文件:       packaging/windows/taskmgr-rs.iss
;
;   日期:       2026年08月20日
;   环境:       Windows x64/ARM64；Inno Setup 6
;   作者:       JamesLinYJ
;   协助:       OpenAI Codex:gpt-5.6-sol
;   参考标准:   Inno Setup 6；Flutter Windows bundle 布局
; --------------------------------------------------------------------------

#ifndef BundleDir
  #error BundleDir must point to the Flutter Windows release bundle
#endif
#ifndef HelperPath
  #error HelperPath must point to taskmgr-helper.exe
#endif
#ifndef OutputDir
  #define OutputDir "."
#endif
#ifndef MyVersion
  #define MyVersion "0.3.0"
#endif
#ifndef MyArch
  #define MyArch "x64compatible"
#endif
#ifndef MyArchLabel
  #define MyArchLabel "x64"
#endif
#ifndef LicensePath
  #define LicensePath "..\..\LICENSE"
#endif
#ifndef SetupIconPath
  #define SetupIconPath "..\..\flutter_app\windows\runner\resources\app_icon.ico"
#endif

[Setup]
AppId={{50B75869-C300-46B7-83EA-18571993A810}
AppName=taskmgr-rs
AppVersion={#MyVersion}
AppPublisher=JamesLinYJ
AppPublisherURL=https://github.com/JamesLinYJ/taskmgr-rs-desktop
AppSupportURL=https://github.com/JamesLinYJ/taskmgr-rs-desktop/issues
DefaultDirName={autopf}\taskmgr-rs
DefaultGroupName=taskmgr-rs
DisableProgramGroupPage=yes
LicenseFile={#LicensePath}
OutputDir={#OutputDir}
OutputBaseFilename=taskmgr-rs-{#MyVersion}-windows-{#MyArchLabel}-setup-unsigned
SetupIconFile={#SetupIconPath}
UninstallDisplayIcon={app}\taskmgr_rs.exe
Compression=lzma2/max
SolidCompression=yes
WizardStyle=classic
PrivilegesRequired=admin
ArchitecturesAllowed={#MyArch}
ArchitecturesInstallIn64BitMode={#MyArch}
CloseApplications=yes
RestartApplications=no
ChangesAssociations=no
ChangesEnvironment=no

#ifdef SignToolName
SignTool={#SignToolName}
#endif

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "chinesesimplified"; MessagesFile: "compiler:Languages\ChineseSimplified.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#BundleDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "{#HelperPath}"; DestDir: "{app}"; DestName: "taskmgr-helper.exe"; Flags: ignoreversion

[Icons]
Name: "{autoprograms}\taskmgr-rs"; Filename: "{app}\taskmgr_rs.exe"
Name: "{autodesktop}\taskmgr-rs"; Filename: "{app}\taskmgr_rs.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\taskmgr_rs.exe"; Description: "{cm:LaunchProgram,taskmgr-rs}"; Flags: nowait postinstall skipifsilent
