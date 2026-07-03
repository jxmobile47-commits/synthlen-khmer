; Synthlen Khmer - Preset Pack Installer (Sound Banks Only)
; Use this to sell additional preset packs separately.
; Build with: ISCC.exe preset-pack.iss
; Requires Inno Setup 6 (free): https://jrsoftware.org/isdl.php
;
; Before building: copy the preset folders you want to include into .\preset-source\

#define PackName       "Synthlen Khmer Preset Pack"
#define PackVersion    "1.0.0"
#define Publisher      "Synthlen Khmer"

[Setup]
AppName={#PackName}
AppVersion={#PackVersion}
AppPublisher={#Publisher}
DefaultDirName={userdocs}\Synthlen Khmer\banks
DefaultGroupName={#PackName}
Compression=lzma2/ultra64
SolidCompression=yes
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64
OutputDir=.\output
OutputBaseFilename=SynthlenKhmer-PresetPack-{#PackVersion}
WizardStyle=modern
LicenseFile=license.rtf
SetupIconFile=icon.ico
; Do not create uninstaller for preset packs - user can delete folders manually
CreateUninstallRegKey=no
Uninstallable=no

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Files]
; Copy all preset folders from .\preset-source\ into the banks directory
Source: ".\preset-source\*"; DestDir: "{userdocs}\Synthlen Khmer\banks"; Flags: recursesubdirs ignoreversion

[Code]
function InitializeSetup(): Boolean;
begin
  Result := True;
end;
