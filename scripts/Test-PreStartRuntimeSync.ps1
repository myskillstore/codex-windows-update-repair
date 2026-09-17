$ErrorActionPreference = 'Stop'
$gate = Join-Path $PSScriptRoot 'sync-bundled-runtime-before-start.ps1'
$global:syncTestState = $null
function powershell.exe {
    $global:LASTEXITCODE = 0
    $global:syncTestState.Calls++
    if ($args -contains '-RepairRuntimeDrift') {
        $global:syncTestState.Repairs++
        $global:syncTestState.Report.Runtime.DriftDetected = $false
        $global:syncTestState.Report.Runtime.RepairRecommended = $false
    }
    $global:syncTestState.Report | ConvertTo-Json -Depth 8
}
function Get-CimInstance { $global:syncTestState.Processes }
function Reset-TestState {
    $global:syncTestState = @{
        Calls = 0; Repairs = 0; Processes = @(); Report = @{
            Package = @{ Version = '1.2.3.0'; BundledManifestExists = $true }
            CodexHome = @{ NeedsRepair = $false }
            Marketplace = @{ SourceMismatch = $false }
            Runtime = @{ DriftDetected = $false; RepairRecommended = $false; RelocatedRuntimeConfigured = $true; Files = @(@{ SourceExists = $true }) }
        }
    }
}
function Invoke-TestGate { & $gate @args -BundledRepairScript $gate -ExpectedPackageVersion '1.2.3.0' }
function Expect-Failure {
    param([scriptblock]$Action)
    $failed = $false
    try { & $Action } catch { $failed = $true }
    if (-not $failed) { throw 'Expected gate failure.' }
    if ($global:syncTestState.Repairs -ne 0) { throw 'Failure case unexpectedly repaired runtime.' }
}
Reset-TestState
$global:syncTestState.Report.Runtime.RepairRecommended = $true
Invoke-TestGate
if ($global:syncTestState.Repairs -ne 0) { throw 'Preview mutated runtime.' }
Reset-TestState
Invoke-TestGate -Apply
if ($global:syncTestState.Repairs -ne 0 -or $global:syncTestState.Calls -ne 2) { throw 'Healthy state was not independently verified.' }
Reset-TestState
$global:syncTestState.Report.Runtime.RepairRecommended = $true
$global:syncTestState.Report.Runtime.DriftDetected = $true
Invoke-TestGate -Apply
if ($global:syncTestState.Repairs -ne 1 -or $global:syncTestState.Calls -ne 3) { throw 'Drift repair/verification ordering failed.' }
Reset-TestState
$global:syncTestState.Report.Runtime.RelocatedRuntimeConfigured = $false
$global:syncTestState.Report.Runtime.DriftDetected = $true
Invoke-TestGate -Apply
if ($global:syncTestState.Repairs -ne 0) { throw 'Unused runtime was enabled.' }
Reset-TestState
$global:syncTestState.Report.Package.Version = '9.0.0.0'
Expect-Failure { Invoke-TestGate -Apply }
Reset-TestState
$global:syncTestState.Report.Runtime.Files[0].SourceExists = $false
Expect-Failure { Invoke-TestGate -Apply }
Reset-TestState
$global:syncTestState.Report.CodexHome.NeedsRepair = $true
Expect-Failure { Invoke-TestGate -Apply }
Reset-TestState
$global:syncTestState.Processes = @([pscustomobject]@{ Name = 'codex.exe' })
Expect-Failure { Invoke-TestGate -Apply }
Write-Output 'PASS: preview, healthy, actionable drift, unused runtime, version change, missing source, path mismatch, and running-process gates.'
