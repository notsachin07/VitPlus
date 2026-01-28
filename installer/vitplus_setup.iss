; VitPlus Inno Setup Script
; Created for proper Windows installation

#define MyAppName "VitPlus"
#define MyAppVersion "2.3.0"
#define MyAppPublisher "VitPlus Team"
#define MyAppURL "https://github.com/notsachin07/VitPlus"
#define MyAppExeName "vitplus.exe"
#define MyAppDescription "VIT-AP WiFi Auto-Login and File Sharing App"

[Setup]
; NOTE: The value of AppId uniquely identifies this application.
; Do not use the same AppId value in installers for other applications.
AppId={{8A7B9C5D-1E2F-4A3B-8C6D-9E0F1A2B3C4D}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}/issues
AppUpdatesURL={#MyAppURL}/releases
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
AllowNoIcons=yes
; Output settings
OutputDir=..\dist
OutputBaseFilename=VitPlus_Setup_{#MyAppVersion}
; Compression
Compression=lzma2/max
SolidCompression=yes
; Appearance
SetupIconFile=..\assets\icons\VitPlus.ico
WizardStyle=modern
; Privileges - install for current user to allow updates without admin
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
; Uninstaller
UninstallDisplayIcon={app}\{#MyAppExeName}
UninstallDisplayName={#MyAppName}
; Version info
VersionInfoVersion={#MyAppVersion}
VersionInfoCompany={#MyAppPublisher}
VersionInfoDescription={#MyAppDescription}
VersionInfoProductName={#MyAppName}
VersionInfoProductVersion={#MyAppVersion}

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked
Name: "startupicon"; Description: "Start VitPlus when Windows starts"; GroupDescription: "Startup:"; Flags: unchecked

[Files]
; Main application files - copy everything from the build output
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
; NOTE: Don't use "Flags: ignoreversion" on any shared system files

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Registry]
; Add to Windows startup if selected
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueType: string; ValueName: "VitPlus"; ValueData: """{app}\{#MyAppExeName}"""; Flags: uninsdeletevalue; Tasks: startupicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[Code]
// Custom code for handling updates and cleanup

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssPostInstall then
  begin
    // Any post-installation tasks can go here
  end;
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
begin
  if CurUninstallStep = usPostUninstall then
  begin
    // Clean up app data if user wants
    if MsgBox('Do you want to remove VitPlus settings and data?', mbConfirmation, MB_YESNO) = IDYES then
    begin
      DelTree(ExpandConstant('{userappdata}\VitPlus'), True, True, True);
      DelTree(ExpandConstant('{localappdata}\VitPlus'), True, True, True);
    end;
  end;
end;

function InitializeSetup(): Boolean;
begin
  Result := True;
  
  // Check if app is running and ask to close it
  if CheckForMutexes('VitPlusMutex') then
  begin
    if MsgBox('VitPlus is currently running. Please close it before installing.', mbError, MB_OKCANCEL) = IDCANCEL then
    begin
      Result := False;
    end;
  end;
end;
