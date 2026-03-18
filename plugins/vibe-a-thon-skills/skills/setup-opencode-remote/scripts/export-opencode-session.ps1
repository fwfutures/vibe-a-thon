param(
    [string]$SessionId = 'ses_30052ecc6ffe0dSN2L9cKFxmB4',
    [string]$Title = 'Greeting quick check-in',
    [string]$CliPath = "$env:LOCALAPPDATA\OpenCode\opencode-cli.exe",
    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $CliPath)) {
    throw "OpenCode CLI not found at: $CliPath"
}

if (-not $OutputPath) {
    $safeTitle = ($Title -replace '[^A-Za-z0-9._ -]', '').Trim()
    if (-not $safeTitle) {
        $safeTitle = $SessionId
    }
    $safeTitle = $safeTitle -replace '\s+', '-'
    $OutputPath = Join-Path -Path (Get-Location) -ChildPath ("{0}-{1}.json" -f $safeTitle, $SessionId)
}

& $CliPath export $SessionId | Out-File -LiteralPath $OutputPath -Encoding utf8

Write-Output "Exported session to: $OutputPath"
