#define AppName "ChronoPlan"
#define AppPublisher "ChronoPlan"
#define AppURL "https://example.com"

; 这些变量由 CI 通过 ISCC 的 /D 参数传入：
; - AppVersion
; - AppExeName
; - SourceDir
; - OutputDir
#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif
#ifndef AppExeName
  #define AppExeName "ChronoPlan.exe"
#endif
#ifndef SourceDir
  #define SourceDir "build\windows\x64\runner\Release"
#endif
#ifndef OutputDir
  #define OutputDir "dist"
#endif

[Setup]
AppId={{7D0A6A21-9F3D-4A7E-9D7F-7B2A7F4D2E1A}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
AppPublisherURL={#AppURL}
AppSupportURL={#AppURL}
AppUpdatesURL={#AppURL}
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
OutputDir={#OutputDir}
OutputBaseFilename={#AppName}-{#AppVersion}-Setup
Compression=lzma
SolidCompression=yes
WizardStyle=modern

[Languages]
Name: "chinesesimplified"; MessagesFile: "compiler:Languages\ChineseSimplified.isl"

[Tasks]
Name: "desktopicon"; Description: "创建桌面快捷方式"; GroupDescription: "附加任务"; Flags: unchecked

[Files]
; 打包 Flutter Windows Release 目录下的全部文件（含 DLL/资源）
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\{#AppExeName}"
Name: "{group}\卸载 {#AppName}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExeName}"; Tasks: desktopicon


