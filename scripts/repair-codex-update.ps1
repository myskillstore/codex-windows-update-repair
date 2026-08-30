[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    [switch]$Apply,

    [ValidateRange(1, 60)]
    [int]$WaitSeconds = 10,

    [string]$PackageFamilyName = 'OpenAI.Codex_2p2nqsd0c76g0'
)

$ErrorActionPreference = 'Stop'

if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) {
    throw 'This repair supports Windows only.'
}

function Get-ParentProcessChain {
    $chain = @()
    $processId = $PID
    $seen = @{}

    while ($processId -and -not $seen.ContainsKey($processId)) {
        $seen[$processId] = $true
        $process = Get-CimInstance Win32_Process -Filter "ProcessId=$processId" -ErrorAction SilentlyContinue
        if (-not $process) { break }

        $chain += [pscustomobject]@{
            Id = [int]$process.ProcessId
            Name = [string]$process.Name
        }
        $processId = [int]$process.ParentProcessId
    }

    return $chain
}

function Get-CodexDesktopProcesses {
    $items = foreach ($process in (Get-Process -Name ChatGPT -ErrorAction SilentlyContinue)) {
        $path = $null
        try { $path = $process.Path } catch { }

        if ($path -match '\\WindowsApps\\OpenAI\.Codex_') {
            [pscustomobject]@{
                Id = $process.Id
                ProcessName = $process.ProcessName
                Path = $path
            }
        }
    }
    return @($items)
}

$packageBefore = Get-AppxPackage -Name OpenAI.Codex -ErrorAction SilentlyContinue
if (-not $packageBefore) {
    throw 'The OpenAI.Codex package is not registered for the current user.'
}

$desktopProcesses = @(Get-CodexDesktopProcesses)

Write-Host "Registered version: $($packageBefore.Version)"
Write-Host "Package status: $($packageBefore.Status)"
Write-Host "Codex desktop processes found: $($desktopProcesses.Count)"

if ($desktopProcesses.Count -gt 0) {
    $desktopProcesses | Select-Object Id, ProcessName, Path | Format-Table -AutoSize
}

if (-not $Apply) {
    Write-Host ''
    Write-Host 'Preview only. No processes were stopped and no package registration was changed.'
    Write-Host 'Re-run from a standalone PowerShell or Windows Terminal with -Apply to continue.'
    return
}

$parentChain = @(Get-ParentProcessChain)
$codexAncestor = $parentChain | Where-Object {
    $_.Name -match '^(ChatGPT|codex|codex-code-mode-host)\.exe$'
} | Select-Object -First 1

if ($codexAncestor) {
    throw "Repair aborted: this PowerShell session is running under $($codexAncestor.Name). Run the script from a standalone Windows Terminal or PowerShell window."
}

$target = "highest staged package for $PackageFamilyName"
if (-not $PSCmdlet.ShouldProcess($target, 'Stop the Codex desktop app and register the package')) {
    return
}

foreach ($process in $desktopProcesses) {
    Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
}

$deadline = (Get-Date).AddSeconds($WaitSeconds)
do {
    Start-Sleep -Milliseconds 500
    $remaining = @(Get-CodexDesktopProcesses)
} while ($remaining.Count -gt 0 -and (Get-Date) -lt $deadline)

if ($remaining.Count -gt 0) {
    throw "Codex desktop processes are still running after $WaitSeconds seconds. Stop them in Task Manager and retry once."
}

Start-Sleep -Seconds 2

try {
    Add-AppxPackage -RegisterByFamilyName `
        -MainPackage $PackageFamilyName `
        -ForceTargetApplicationShutdown `
        -ErrorAction Stop
} catch {
    throw "Package registration failed: $($_.Exception.Message)"
}

$packageAfter = Get-AppxPackage -Name OpenAI.Codex -ErrorAction Stop
$advanced = [version]$packageAfter.Version -gt [version]$packageBefore.Version

[pscustomobject]@{
    Name = $packageAfter.Name
    PreviousVersion = $packageBefore.Version.ToString()
    CurrentVersion = $packageAfter.Version.ToString()
    Status = $packageAfter.Status.ToString()
    VersionAdvanced = $advanced
} | Format-List

if (-not $advanced) {
    Write-Warning 'Registration completed, but the package version did not advance. Do not repeat in a loop; collect diagnostics and inspect the Store/AppX events.'
} else {
    Write-Host 'Codex update registration completed. Start Codex manually and check for any later rollout version.'
}
