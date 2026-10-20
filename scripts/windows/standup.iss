; Inno Setup script for the CNPS StandUp Windows desktop build.
;
; Why an installer at all: the release pipeline shipped a zip containing a raw
; standup_app.exe. A user who extracts it has no Start Menu entry, no Add/Remove
; Programs entry, no way to uninstall short of deleting the folder, and no
; upgrade path. This produces a real installer for both.
;
; Verified constraints, all of which this script has to respect:
;
;  * The bundle is FLAT. windows/runner/main.cpp does
;    `flutter::DartProject project(L"data")`, so standup_app.exe, the five
;    plugin DLLs and data/ must sit together in ONE directory. Relocating the
;    DLLs or moving data/ breaks the app. [Files] therefore copies the whole
;    Release tree, including its data/ subdirectory.
;
;  * Nothing mutable lives under the install directory. The Drift database is
;    at %USERPROFILE%\Documents\standup_app.sqlite and SharedPreferences is
;    under %APPDATA%\com.cnps\... - both per user, neither touched by
;    this script. Uninstalling removes the program and leaves user data alone,
;    so reinstalling restores the user's history.
;
;  * The app runs asInvoker (windows/runner/runner.exe.manifest declares no
;    requestedExecutionLevel), so it never needs elevation. Installing per-user
;    keeps that property and means no UAC prompt on locked-down machines.
;
;  * The binary is UNSIGNED. An unsigned binary triggers SmartScreen whatever
;    packaging it arrives in; the installer does not remove that warning, it
;    only makes the install itself uneventful. See the "Windows may warn you"
;    section of docs/INSTALL_AND_LAUNCH.md. To sign, pass
;    /DSignToolCommand=signtool /a $f /fd SHA256 /n "CNPS" /p <password>.

#define AppName "CNPS StandUp"
#define AppPublisher "CNPS"
#define AppExeName "standup_app.exe"

#ifndef AppVersion
  #define AppVersion "1.0.1"
#endif
#ifndef BuildRoot
  #define BuildRoot "..\..\build\windows\x64\runner\Release"
#endif
#ifndef OutputDir
  #define OutputDir "..\..\dist"
#endif
#ifndef SignToolCommand
  // Intentionally left undefined: the build is unsigned today. SignTool must
  // not be emitted with an empty value, because ISCC rejects a directive with
  // no arguments, and naming a signtool that is not on PATH fails the build
  // outright. So the whole directive is conditional. To sign, pass
  //   /DSignToolCommand=signtool /a $f /fd SHA256 /n "CNPS" /p <password>
  // from CI when a certificate secret is configured.
#endif

[Setup]
AppId={{6F2A1C64-6B4E-4E1E-9F0B-1B7A5D3C9E21}
AppName={#AppName}
AppVersion=1.0.3
AppVerName={#AppName} {#AppVersion}
AppPublisher=CNPS
DefaultDirName={localappdata}\Programs\CNPS StandUp
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
OutputDir={#OutputDir}
OutputBaseFilename=standup-{#AppVersion}-windows-x64-setup
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
; Per-user. The app never elevates, and requiring admin would add a UAC prompt
; the app itself does not need.
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
UninstallDisplayIcon={app}\{#AppExeName}
UninstallDisplayName={#AppName}
; Inno's SetupIconFile requires an .ico, not the PNG brand asset.
SetupIconFile=..\..\windows\runner\resources\app_icon.ico
VersionInfoVersion={#AppVersion}
VersionInfoProductName={#AppName}
VersionInfoCompany={#AppPublisher}
VersionInfoDescription={#AppName} Setup
#ifdef SignToolCommand
SignTool={#SignToolCommand}
#endif
CloseApplications=yes
RestartApplications=no

[Files]
; The whole Release tree, flat, exactly as `flutter build windows` emits it.
; `data\**\*` is required: main.cpp resolves the bundle relative to the exe.
Source: "{#BuildRoot}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\{#AppExeName}"
Name: "{group}\Uninstall {#AppName}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExeName}"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "Create a &desktop shortcut"; GroupDescription: "Additional icons:"

[Run]
Filename: "{app}\{#AppExeName}"; Description: "Launch {#AppName}"; Flags: nowait postinstall skipifsilent
