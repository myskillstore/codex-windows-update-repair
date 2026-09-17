[CmdletBinding()]
param(
    [switch]$Apply,
    [string]$BundledRepairScript,
    [string]$ExpectedPackageVersion
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($BundledRepairScript)) {
    $BundledRepairScript = Join-Path $PSScriptRoot '..\..\codex-windows-bundled-plugin-repair\scripts\Repair-CodexBundledPlugins.ps1'
}
if (-not (Test-Path -LiteralPath $BundledRepairScript -PathType Leaf)) {
    throw 'Install codex-windows-bundled-plugin-repair alongside this skill, or supply -BundledRepairScript. Nothing was changed.'
}

function Get-BundledHealth {
    param([switch]$Repair)
    $arguments = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $BundledRepairScript, '-SkipCliInspection', '-Json')
    if ($Repair) { $arguments += '-RepairRuntimeDrift' } else { $arguments += '-InspectOnly' }
    $output = & powershell.exe @arguments
    if ($LASTEXITCODE -ne 0) { throw "Bundled runtime helper failed (exit $LASTEXITCODE). Do not start Codex until reviewed." }
    $output | Out-String | ConvertFrom-Json
}

function Assert-StaticHealth {
    param($Report)
    if ($ExpectedPackageVersion -and $Report.Package.Version -ne $ExpectedPackageVersion) {
        throw 'The registered AppX version changed during the workflow. Stop and inspect before retrying.'
    }
    if (-not $Report.Package.BundledManifestExists -or @($Report.Runtime.Files).Count -eq 0 -or
        @($Report.Runtime.Files | Where-Object { -not $_.SourceExists }).Count -gt 0) {
        throw 'The registered AppX bundle is incomplete or unsupported. Do not synchronize partial runtime files.'
    }
    if ($Report.CodexHome.NeedsRepair -or $Report.Marketplace.SourceMismatch) {
        throw 'A path or marketplace mismatch needs separate authorization; this workflow only synchronizes runtime drift.'
    }
}

$before = Get-BundledHealth
Assert-StaticHealth $before
Write-Host "Registered package: $($before.Package.Version); runtime repair recommended: $($before.Runtime.RepairRecommended)"
if (-not $Apply) {
    Write-Host 'Preview only: CLI inspection was skipped; no files, environment, configuration, or processes were changed.'
    return
}

function Assert-CodexClosed {
    # Never stop a desktop app that the Store or another updater unexpectedly relaunched.
    $active = @(Get-CimInstance Win32_Process -ErrorAction Stop | Where-Object {
        $_.Name -in @('ChatGPT.exe', 'Codex.exe', 'codex.exe', 'node_repl.exe', 'codex-code-mode-host.exe')
    })
    if ($active.Count -gt 0) { throw 'Codex or its runtime is running. Fully close it and rerun this synchronization from standalone PowerShell.' }
}
Assert-CodexClosed
if ($before.Runtime.RepairRecommended) {
    $repaired = Get-BundledHealth -Repair
    Assert-StaticHealth $repaired
}
$after = Get-BundledHealth
Assert-StaticHealth $after
if ($after.Runtime.RepairRecommended) { throw 'Runtime drift remains after synchronization. Stop; do not retry in a loop.' }
Assert-CodexClosed
Write-Host 'Pre-start checks passed. No desktop app was launched. Start Codex manually and verify Browser/Chrome in a fresh task.'
if (-not $after.Runtime.RelocatedRuntimeConfigured -and $after.Runtime.DriftDetected) {
    Write-Host 'Unused relocated runtime differs; it was left unchanged because no relocated runtime override is configured.'
}
