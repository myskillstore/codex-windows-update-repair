# Diagnostics and evidence interpretation

Use this reference for read-only diagnosis. Collect only the evidence needed to distinguish package-update behavior from a desktop crash.

## Evidence sources

### Registered package

```powershell
Get-AppxPackage -Name OpenAI.Codex |
  Select-Object Name, PackageFullName, Version, Status, InstallLocation
```

The registered version is the version Windows currently launches. A newer version mentioned in logs may be downloaded or staged without being registered.

### Active package processes

The desktop executable is named `ChatGPT.exe` even when the package identity is `OpenAI.Codex`. Multiple `ChatGPT.exe` processes are normal for an Electron application; the important question is whether any process from the `OpenAI.Codex_*` WindowsApps package remains alive during registration.

### Codex desktop updater logs

Search recent files below `%LOCALAPPDATA%\Codex\Logs` only for updater-specific markers:

- `[windows-store-updater]`
- `[sparkle]`
- `manifestBuildVersion=`
- `update_resume_state_saved`
- `cause=stop_process`

Avoid copying unrelated log lines because they can contain task or conversation context.

Interpret the fields separately:

- `buildVersion`: running desktop build.
- `manifestBuildVersion`: version advertised to the desktop updater.
- `hasUpdate=true`: Store API reported an update.
- `download_completed`: download/staging completed; it does not prove registration succeeded.

### Store and AppX events

Relevant channels include:

- `Microsoft-Windows-Store/Operational`
- `Microsoft-Windows-AppXDeployment/Operational`
- `Microsoft-Windows-AppXDeploymentServer/Operational`
- `Microsoft-Windows-AppxPackaging/Operational`

High-signal patterns:

- `Stage` succeeded but `Register` did not occur: the package is downloaded but inactive.
- `RegisterByPackageFamilyName` followed by `0x80070005` and a message requiring `OpenAI.Codex_...!App` to close: a running package process blocked registration.
- `BlockedOnUser`: Store is waiting for an application-close or user-controlled installation boundary.
- `0x80004004` / `E_ABORT`: an earlier fulfillment attempt was aborted; inspect the later attempt instead of assuming permanent corruption.

### Crash evidence

Crashpad sidecars under `%APPDATA%\Codex\web\Codex\Crashpad\reports` with `"capture_kind":"crash"` support a crash conclusion. Their timestamps can be compared with update checks and registration attempts.

An app closing after the user presses Update is expected updater behavior. It is not a crash unless crash evidence exists at that time.

## Version disagreement

It is possible to observe three versions simultaneously:

1. The registered/running version.
2. A Store package version that has been downloaded or staged.
3. A newer manifest version advertised by a rollout service.

`winget show` can return `Version: Unknown` for Microsoft Store products, and `winget list` may fail to correlate the Store product ID with the installed AppX identity. In that state, “no applicable upgrade” is not proof that the installed package is current.

## Reporting

State conclusions with timestamps and evidence. Separate verified facts from inference, and redact local paths, usernames, SIDs, tokens, and task content before sharing a report.
