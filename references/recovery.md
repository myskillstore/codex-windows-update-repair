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

The script stops only `ChatGPT.exe` processes whose executable path belongs to the `OpenAI.Codex_*` WindowsApps package. It then asks Windows to register the highest staged package for the current user by package family name.

The script does not remove the existing package, reset application data, delete `<CODEX_HOME>`, or start Codex automatically.

## Failure handling

- If the script detects that it is running under Codex, it stops before changing anything. Re-run it from a standalone terminal.
- If package registration still reports that Codex must close, use Task Manager to confirm no package-owned `ChatGPT.exe` remains, then make one more user-authorized attempt.
- If registration returns Access Denied without a package-in-use message, retry once from a standalone PowerShell opened as Administrator.
- If no higher staged version exists or the registered version does not advance, open Microsoft Store, visit the Codex/ChatGPT product page, and request the update there.
- If Store remains inconsistent, use Windows Settings > Apps > Installed apps > Codex > Advanced options > Terminate, then Repair. Recheck before considering Reset.
- Reset or uninstall/reinstall only when the user explicitly chooses it after backing up local state. These actions are not part of the routine script.

## Stopping condition

Stop after one normal registration attempt and, when justified, one elevated retry. Report the exact error and preserve the existing package and data rather than repeatedly forcing installation.
