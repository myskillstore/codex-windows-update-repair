# Codex Windows Update Repair

## Optional post-update, pre-start runtime synchronization

For installations already configured to use relocated runtimes, add `-SyncBundledRuntime`: after registration advances, inspect statically, synchronize only actionable mismatches, verify, and start Codex manually. Running Codex, missing sources, or path mismatches stop the gate.

```powershell
.\scripts\repair-codex-update.ps1 -SyncBundledRuntime
.\scripts\repair-codex-update.ps1 -Apply -SyncBundledRuntime
```

Install the sibling `codex-windows-bundled-plugin-repair` skill and authorize registration plus runtime/related configuration/user-environment synchronization. For a completed Store update, close Codex, preview, and authorize `scripts/sync-bundled-runtime-before-start.ps1 -Apply`. See [recovery](references/recovery.md). Browser connectivity still needs a fresh-task test after startup.

Codex Windows Update Repair 是一个用于诊断和修复 Windows 上 Codex 桌面版更新卡住问题的开源 Skill，重点处理“点击更新后应用关闭，但版本没有变化”这类 Microsoft Store/MSIX 注册故障。
Codex Windows Update Repair is an open-source skill for diagnosing and repairing stuck Codex desktop updates on Windows, especially Microsoft Store/MSIX registration failures where the app closes but the installed version does not change.

[中文说明](README.md)

## Why this exists

The Codex desktop app on Windows can expose several conflicting states at once: the app reports an update while `winget` reports none; a newer package is downloaded or staged while Windows still launches the old version; or pressing Update closes the app but AppX registration starts before the Electron processes have fully exited.

The UI alone cannot reliably distinguish these cases. `download_completed` does not prove that the new package is active, and a Microsoft Store product reported as `Version: Unknown` gives `winget` no useful version to compare. Repeatedly pressing Update, resetting the app, or reinstalling may interrupt work or affect local state without establishing the cause.

This skill builds an evidence timeline first, then distinguishes among:

- an expected update-triggered shutdown;
- an Electron/Chromium browser-process crash;
- an MSIX package that was downloaded but not registered;
- AppX registration blocked by a lingering package process;
- version disagreement between Store, the in-app update manifest, and `winget`.

Repair is preview-only by default. After explicit user authorization, the script stops only desktop processes owned by the Codex Windows package and asks Windows to register the highest staged version. It does not reset, uninstall, or delete Codex data.

## When to use it

Use it when:

- Codex keeps showing an available update;
- pressing Update closes Codex but the app does not relaunch;
- reopening Codex still shows the update;
- `winget upgrade` reports no applicable upgrade while the app reports one;
- AppX/Store logs contain `BlockedOnUser`, `0x80070005`, or a request to close `OpenAI.Codex`;
- you need to determine whether an unexplained exit was a crash or update behavior.

Do not use it for ordinary Codex CLI upgrades or unrelated Windows applications.

## Installation

Clone the repository into the Codex Skills directory:

```powershell
$skillsRoot = if ($env:CODEX_HOME) {
  Join-Path $env:CODEX_HOME 'skills'
} else {
  Join-Path $env:USERPROFILE '.codex\skills'
}

git clone https://github.com/myskillstore/codex-windows-update-repair.git `
  (Join-Path $skillsRoot 'codex-windows-update-repair')
```

When `CODEX_HOME` is unset, this command automatically falls back to the default `~/.codex/skills` directory.

Restart Codex, then invoke the skill explicitly:

```text
Use $codex-windows-update-repair to diagnose why my Codex Windows update is stuck.
```

## Run the diagnostic directly

Read-only diagnostics:

```powershell
.\scripts\diagnose-codex-update.ps1
```

Write a JSON report with basic local-path redaction:

```powershell
.\scripts\diagnose-codex-update.ps1 -OutputPath .\codex-update-diagnostics.json
```

Review the report for sensitive information before sharing it.

## Repair a staged but unregistered update

Run this from a standalone Windows Terminal or PowerShell window, never from the Codex integrated terminal.

Preview first:

```powershell
.\scripts\repair-codex-update.ps1
```

After saving active work, apply the repair:

```powershell
.\scripts\repair-codex-update.ps1 -Apply
```

The script presents another high-impact confirmation. After completion, start Codex manually and verify the registered version:

```powershell
Get-AppxPackage -Name OpenAI.Codex |
  Select-Object Name, Version, Status
```

## Safety boundaries

- Diagnostics are read-only by default.
- Repair requires `-Apply` and PowerShell confirmation.
- The repair refuses to run when its process tree is owned by Codex.
- It does not delete logs, sessions, projects, or `<CODEX_HOME>`.
- It does not automatically reset, uninstall, or reinstall the app.
- It reports registration failure instead of retrying indefinitely.

## Repository layout

```text
SKILL.md
agents/openai.yaml
references/diagnostics.md
references/recovery.md
scripts/diagnose-codex-update.ps1
scripts/repair-codex-update.ps1
README.md
README.en.md
```

## License

[MIT License](LICENSE)
