[CmdletBinding()]
param(
    [ValidateRange(1, 30)]
    [int]$LookbackDays = 3,

    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'

if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) {
    throw 'This diagnostic supports Windows only.'
}

$startTime = (Get-Date).AddDays(-$LookbackDays)
$packageName = 'OpenAI.Codex'
$packageFamilyName = 'OpenAI.Codex_2p2nqsd0c76g0'
$logRoot = Join-Path $env:LOCALAPPDATA 'Codex\Logs'
$crashRoot = Join-Path $env:APPDATA 'Codex\web\Codex\Crashpad\reports'

function Protect-DiagnosticText {
    param([AllowNull()][string]$Text)

    if ($null -eq $Text) { return $null }

    $protected = $Text
    $replacements = @(
        @($env:USERPROFILE, '<HOME>'),
        @($env:LOCALAPPDATA, '<LOCALAPPDATA>'),
        @($env:APPDATA, '<APPDATA>'),
        @([Environment]::UserName, '<USER>')
    )

    foreach ($replacement in $replacements) {
        if (-not [string]::IsNullOrWhiteSpace($replacement[0])) {
            $protected = $protected -replace [regex]::Escape($replacement[0]), $replacement[1]
        }
    }

    $protected = $protected -replace 'S-1-5-21-(?:\d+-){3}\d+', '<USER_SID>'
    return $protected
}

function Get-CodexPackageProcesses {
    $items = foreach ($process in (Get-Process -Name ChatGPT -ErrorAction SilentlyContinue)) {
        $path = $null
        $processStartTime = $null
        try { $path = $process.Path } catch { }
        try { $processStartTime = $process.StartTime } catch { }

        [pscustomobject]@{
            Id = $process.Id
            ProcessName = $process.ProcessName
            StartTime = $processStartTime
            IsCodexPackageProcess = [bool]($path -match '\\WindowsApps\\OpenAI\.Codex_')
            Path = Protect-DiagnosticText $path
        }
    }
    return @($items)
}

$registeredPackage = Get-AppxPackage -Name $packageName -ErrorAction SilentlyContinue |
    Select-Object Name, PackageFullName, Version, Status, InstallLocation

$updaterLines = @()
if (Test-Path -LiteralPath $logRoot) {
    $recentLogs = Get-ChildItem -LiteralPath $logRoot -File -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -ge $startTime }

    if ($recentLogs) {
        $updaterLines = Select-String -LiteralPath $recentLogs.FullName -Pattern @(
            '\[windows-store-updater\]',
            '\[sparkle\]',
            'update_resume_state_saved',
            'cause=stop_process'
        ) -CaseSensitive:$false -ErrorAction SilentlyContinue |
            Sort-Object Path, LineNumber |
            Select-Object -Last 200 |
            ForEach-Object {
                [pscustomobject]@{
                    File = Protect-DiagnosticText $_.Path
                    LineNumber = $_.LineNumber
                    Text = Protect-DiagnosticText $_.Line
                }
            }
    }
}

$crashReports = @()
if (Test-Path -LiteralPath $crashRoot) {
    $crashReports = Get-ChildItem -LiteralPath $crashRoot -File -Filter '*_sidecar.json' -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -ge $startTime } |
        Sort-Object LastWriteTime |
        ForEach-Object {
            $captureKind = $null
            $processType = $null
            try {
                $sidecar = Get-Content -Raw -LiteralPath $_.FullName | ConvertFrom-Json
                $captureKind = $sidecar.capture_kind
                $processType = $sidecar.ptype
            } catch { }

            [pscustomobject]@{
                Time = $_.LastWriteTime
                CaptureKind = $captureKind
                ProcessType = $processType
                File = Protect-DiagnosticText $_.FullName
            }
        }
}

$eventLogs = @(
    'Microsoft-Windows-Store/Operational',
    'Microsoft-Windows-AppXDeployment/Operational',
    'Microsoft-Windows-AppXDeploymentServer/Operational',
    'Microsoft-Windows-AppxPackaging/Operational'
)

$deploymentEvents = foreach ($eventLog in $eventLogs) {
    Get-WinEvent -FilterHashtable @{ LogName = $eventLog; StartTime = $startTime } -ErrorAction SilentlyContinue |
        Where-Object {
            $_.Message -match [regex]::Escape($packageFamilyName) -and
            $_.Message -match 'Stage|Register|BlockedOnUser|0x80070005|0x80004004|需要关闭|must be closed|StateTransition'
        } |
        Select-Object -Last 100 |
        ForEach-Object {
            [pscustomobject]@{
                Time = $_.TimeCreated
                Log = $eventLog
                Id = $_.Id
                Level = $_.LevelDisplayName
                Message = Protect-DiagnosticText (($_.Message -replace '\s+', ' ').Trim())
            }
        }
}

$applicationCrashes = Get-WinEvent -FilterHashtable @{ LogName = 'Application'; StartTime = $startTime } -ErrorAction SilentlyContinue |
    Where-Object {
        $_.ProviderName -in @('Application Error', 'Windows Error Reporting', 'Application Hang') -and
        $_.Message -match 'ChatGPT|OpenAI\.Codex|codex\.exe'
    } |
    Select-Object -Last 50 |
    ForEach-Object {
        [pscustomobject]@{
            Time = $_.TimeCreated
            Provider = $_.ProviderName
            Id = $_.Id
            Message = Protect-DiagnosticText (($_.Message -replace '\s+', ' ').Trim())
        }
    }

$allUpdaterText = ($updaterLines.Text -join "`n")
$manifestVersions = [regex]::Matches($allUpdaterText, 'manifestBuildVersion=(?<version>\d+(?:\.\d+){3})') |
    ForEach-Object { $_.Groups['version'].Value } |
    Select-Object -Unique

$allDeploymentText = ($deploymentEvents.Message -join "`n")
$stagedVersions = [regex]::Matches($allDeploymentText, 'OpenAI\.Codex_(?<version>\d+(?:\.\d+){3})_') |
    ForEach-Object { $_.Groups['version'].Value } |
    Select-Object -Unique

$findings = [ordered]@{
    HasRegisteredPackage = [bool]$registeredPackage
    HasAdvertisedUpdate = [bool]($allUpdaterText -match 'hasUpdate=true')
    HasPackageCloseRegistrationFailure = [bool](
        $allDeploymentText -match '0x80070005' -and
        $allDeploymentText -match '需要关闭|must be closed|OpenAI\.Codex_.*!App'
    )
    HasBlockedOnUserState = [bool]($allDeploymentText -match 'BlockedOnUser')
    HasCrashpadCrash = [bool]($crashReports.CaptureKind -contains 'crash')
}

$report = [ordered]@{
    GeneratedAt = Get-Date
    LookbackDays = $LookbackDays
    RegisteredPackage = $registeredPackage | ForEach-Object {
        [pscustomobject]@{
            Name = $_.Name
            PackageFullName = $_.PackageFullName
            Version = $_.Version.ToString()
            Status = $_.Status.ToString()
            InstallLocation = Protect-DiagnosticText $_.InstallLocation
        }
    }
    ManifestVersions = @($manifestVersions)
    ObservedPackageVersions = @($stagedVersions)
    Processes = @(Get-CodexPackageProcesses)
    Findings = $findings
    UpdaterLines = @($updaterLines)
    CrashReports = @($crashReports)
    DeploymentEvents = @($deploymentEvents | Sort-Object Time)
    ApplicationCrashEvents = @($applicationCrashes | Sort-Object Time)
}

$json = $report | ConvertTo-Json -Depth 8

if ($OutputPath) {
    $parent = Split-Path -Parent $OutputPath
    if ($parent -and -not (Test-Path -LiteralPath $parent)) {
        throw "Output directory does not exist: $parent"
    }
    Set-Content -LiteralPath $OutputPath -Value $json -Encoding UTF8
    Write-Host "Diagnostic report written to: $OutputPath"
    Write-Warning 'Review the report for sensitive information before sharing it.'
} else {
    $json
}
