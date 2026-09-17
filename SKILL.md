---
name: codex-windows-update-repair
description: Diagnose and repair stuck Windows Codex Desktop updates and perform post-update, pre-start runtime consistency checks. Use for Store/MSIX registration failures or authorized manual updates with relocated runtimes; not ordinary Codex CLI upgrades.
---

# Codex Windows Update Repair

Diagnose the Windows Codex desktop package before changing it, distinguish update failures from application crashes, and use the least destructive recovery that fits the evidence.

## Required workflow

1. Start read-only. Record the installed `OpenAI.Codex` AppX version, active package processes, recent Codex updater lines, Crashpad report timestamps, and relevant Microsoft Store/AppX deployment events. Prefer `scripts/diagnose-codex-update.ps1` when available.
2. Establish a timeline. Do not call an update-triggered shutdown a crash unless Crashpad or Windows events support that conclusion. Do not treat `winget upgrade` reporting no update as authoritative when the Store product version is `Unknown` or inventory matching fails.
3. Classify the failure before proposing a repair. Common evidence includes a newer package being staged, `RegisterByPackageFamilyName` failing with `0x80070005`, or an event saying the Codex app must be closed.
4. Preserve active work. Before stopping the desktop app or registering a package, tell the user that current Codex tasks will be interrupted and obtain explicit authorization for the mutation.
5. Run repair only from a standalone Windows Terminal or PowerShell process. Never launch the repair from the Codex integrated terminal or an agent shell whose ancestor is Codex; closing the app would terminate the repair itself.
6. Prefer registering the highest already-staged Store package over resetting or uninstalling the app. Use `scripts/repair-codex-update.ps1` in preview mode first, then with `-Apply` only after authorization.
7. Verify the registered package version and status after repair. If the version did not advance, stop and report the exact AppX/Store error. Do not loop, reset, or uninstall automatically.
8. For updates with configured relocated runtimes, recommend previewing `-SyncBundledRuntime` and, after explicit authorization covering both package registration and runtime/config/environment synchronization, running `-Apply -SyncBundledRuntime`. Keep Codex closed until the static post-update gate passes. Read [references/recovery.md](references/recovery.md) for dependency and standalone synchronization commands. Do not claim Browser/Chrome works until tested after startup in a fresh task.

## Scenario references

- Read [references/diagnostics.md](references/diagnostics.md) when interpreting updater logs, Store/AppX events, Crashpad evidence, or version disagreement.
- Read [references/recovery.md](references/recovery.md) before any package registration, Store repair, reset, or reinstall recommendation.

## Safety boundaries

- Diagnosis is read-only unless the user explicitly supplies an output path for a report.
- Package registration requires explicit authorization immediately before execution.
- Never delete Codex sessions, logs, application data, or `<CODEX_HOME>` as part of routine repair.
- Treat Reset and uninstall/reinstall as last-resort user-directed actions and recommend backing up local state first.
- Redact usernames, home paths, SIDs, tokens, and conversation content before sharing diagnostics.
