# Recovery procedure

Read this reference before changing package registration or recommending Store reset/reinstallation.

## Recovery order

1. Finish or pause active Codex tasks.
2. Preview the repair from a standalone PowerShell or Windows Terminal:

   ```powershell
   .\scripts\repair-codex-update.ps1
   ```

3. Review the installed version and the package processes that would be stopped.
4. After explicit authorization, apply the repair:

   ```powershell
   .\scripts\repair-codex-update.ps1 -Apply
   ```

5. Verify with:

   ```powershell
   Get-AppxPackage -Name OpenAI.Codex |
     Select-Object Name, Version, Status
   ```

6. Start Codex manually and check whether another rollout version is offered.

## What the repair does

### Optional pre-start runtime synchronization

Install `codex-windows-bundled-plugin-repair` beside this skill. Preview and apply the combined workflow:

```powershell
.\scripts\repair-codex-update.ps1 -SyncBundledRuntime
.\scripts\repair-codex-update.ps1 -Apply -SyncBundledRuntime
```

Use `-BundledRepairScript "<bundled-skill>\scripts\Repair-CodexBundledPlugins.ps1"` if the skills are not siblings. A missing dependency aborts before package registration. The apply confirmation includes backup and synchronization of runtime files and related configuration/user environment entries; obtain explicit authorization for that full scope.

After the registered version advances, the script inspects without launching Codex CLI or Desktop, synchronizes only actionable drift when relocated runtimes are already configured, and repeats inspection before suggesting manual startup. It does not materialize plugins, reset caches, change marketplace paths, or enable an unused relocated runtime. Missing AppX sources, version changes, path mismatches, or an unexpectedly running Codex abort the gate. Do not start Codex until the failure is reviewed. Keep backups from the bundled helper.

For a Store/manual update already completed, fully close Codex and use the standalone gate (preview first, apply only after runtime/config/environment authorization):

```powershell
.\scripts\sync-bundled-runtime-before-start.ps1
.\scripts\sync-bundled-runtime-before-start.ps1 -Apply
```

This standalone command does not require a further version advance. Existing materialized plugin caches may remain old until startup; actual Browser/Chrome and fresh-task capability checks still happen after reopening. If registration did not advance, the combined script does not synchronize or retry automatically.

The script stops only `ChatGPT.exe` processes whose executable path belongs to the `OpenAI.Codex_*` WindowsApps package. It then asks Windows to register the highest staged package for the current user by package family name.

The script does not remove the existing package, reset application data, delete `<CODEX_HOME>`, or start Codex automatically.

## Failure handling

- The repair helper reports whether its current token is elevated. For a known packaged-service elevation requirement, run the preview with `-RequireAdministrator -SyncBundledRuntime`, then authorize `-Apply -RequireAdministrator -SyncBundledRuntime` in a standalone elevated terminal under the same Windows account. The required-token check runs before process shutdown and registration. It does not automatically discover every staged manifest requirement, self-elevate, or guarantee that other deployment errors cannot occur.

- If the detailed deployment error is `0x80073D28` and says administrator privileges are required to install a packaged service (`windows.service`), request one user-authorized retry from a standalone terminal opened as Administrator under the same Windows account. A wrapper error `0x80073CF6` alone is insufficient for this classification. Do not automatically elevate or run as a different administrator account: package registration and user environment synchronization are user-specific. Retain the apply confirmation and pre-start runtime gate. If termination succeeded before this error, app reopening is not evidence that running processes caused this attempt to fail. Stop if the elevated retry fails and preserve its detailed deployment error.

- If the script detects that it is running under Codex, it stops before changing anything. Re-run it from a standalone terminal.
- If package registration still reports that Codex must close, use Task Manager to confirm no package-owned `ChatGPT.exe` remains, then make one more user-authorized attempt.
- If registration returns Access Denied without a package-in-use message, retry once from a standalone PowerShell opened as Administrator.
- If no higher staged version exists or the registered version does not advance, open Microsoft Store, visit the Codex/ChatGPT product page, and request the update there.
- If Store remains inconsistent, use Windows Settings > Apps > Installed apps > Codex > Advanced options > Terminate, then Repair. Recheck before considering Reset.
- Reset or uninstall/reinstall only when the user explicitly chooses it after backing up local state. These actions are not part of the routine script.

## Stopping condition

Stop after one normal registration attempt and, when justified, one elevated retry. Report the exact error and preserve the existing package and data rather than repeatedly forcing installation.
