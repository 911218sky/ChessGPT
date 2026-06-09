#ifndef AppVersion
  #define AppVersion "0.0.0-dev"
#endif

#ifndef AppPublisher
  #define AppPublisher "911218sky"
#endif

#ifndef SourceDir
  #define SourceDir "..\\..\\build\\windows\\x64\\runner\\Release"
#endif

#ifndef OutputDir
  #define OutputDir "..\\..\\artifacts"
#endif

[Setup]
AppId={{A1F25087-6E05-42DD-B6C2-0C25B0A7F7E8}
AppName=ChessGPT
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
DefaultDirName={localappdata}\ChessGPT
DefaultGroupName=ChessGPT
DisableProgramGroupPage=yes
OutputDir={#OutputDir}
OutputBaseFilename=chess_ai_desktop_{#AppVersion}_windows_setup
Compression=lzma
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=lowest
ArchitecturesInstallIn64BitMode=x64compatible
UninstallDisplayIcon={app}\chessgpt.exe

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Additional shortcuts:"; Flags: unchecked

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs; Excludes: "settings.json"

[Icons]
Name: "{autoprograms}\ChessGPT"; Filename: "{app}\chessgpt.exe"
Name: "{autodesktop}\ChessGPT"; Filename: "{app}\chessgpt.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\chessgpt.exe"; Description: "Launch ChessGPT"; Flags: nowait postinstall skipifsilent
