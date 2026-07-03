; Synthlen Khmer - Full Plugin Installer (VST3 + Standalone + All Presets)
; Build with: ISCC.exe full-installer.iss
; Requires Inno Setup 6 (free): https://jrsoftware.org/isdl.php

#define PluginName      "Synthlen Khmer"
#define PluginVersion   "1.0.0"
#define Publisher       "Synthlen Khmer"
#define Vst3Source      "..\build\SynthlenKhmer_artefacts\Release\VST3\Synthlen Khmer.vst3"
#define StandaloneSource "..\build\SynthlenKhmer_artefacts\Release\Standalone"
#define BanksSource     "{userdocs}\Synthlen Khmer\banks"

[Setup]
AppName={#PluginName}
AppVersion={#PluginVersion}
AppPublisher={#Publisher}
DefaultDirName={commonpf}\{#PluginName}
DefaultGroupName={#PluginName}
Compression=lzma2/ultra64
SolidCompression=yes
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64
DiskSpanning=yes
DiskSliceSize=1000000000
OutputDir=.\output
OutputBaseFilename=SynthlenKhmer-Setup-{#PluginVersion}
UninstallDisplayIcon={app}\Synthlen Khmer.exe
WizardStyle=modern
LicenseFile=license.rtf
SetupIconFile=icon.ico

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "vst3"; Description: "Install VST3 plugin"; GroupDescription: "Components:"
Name: "standalone"; Description: "Install Standalone application"; GroupDescription: "Components:"
Name: "presets"; Description: "Install all preset sound banks (2.4 GB)"; GroupDescription: "Components:"

[Files]
; VST3 plugin
Source: "{#Vst3Source}"; DestDir: "{commoncf}\VST3"; Flags: recursesubdirs ignoreversion; Tasks: vst3

; Standalone executable + WebView2 runtime folder
Source: "{#StandaloneSource}\Synthlen Khmer.exe"; DestDir: "{app}"; Flags: ignoreversion; Tasks: standalone
Source: "{#StandaloneSource}\Synthlen Khmer.exe.WebView2\*"; DestDir: "{app}\Synthlen Khmer.exe.WebView2"; Flags: recursesubdirs ignoreversion; Tasks: standalone

; Preset banks - all 45 instrument folders
Source: "{#BanksSource}\*"; DestDir: "{userdocs}\Synthlen Khmer\banks"; Flags: recursesubdirs ignoreversion; Tasks: presets

[Icons]
Name: "{group}\Synthlen Khmer"; Filename: "{app}\Synthlen Khmer.exe"; Tasks: standalone
Name: "{group}\Uninstall Synthlen Khmer"; Filename: "{uninstallexe}"

[Run]
Filename: "{app}\Synthlen Khmer.exe"; Description: "Launch Synthlen Khmer"; Flags: nowait postinstall skipifsilent; Tasks: standalone

[UninstallDelete]
Type: filesandordirs; Name: "{userdocs}\Synthlen Khmer\banks"
