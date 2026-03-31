param(
    [string]$ConfigPath = '.\tools\GoogleCalendar.config.json',
    [AllowNull()]
    [string]$Use12HourTime,
    [switch]$Toggle
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Resolve-ProjectPath {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if ([System.IO.Path]::IsPathRooted($Path)) {
        return [System.IO.Path]::GetFullPath($Path)
    }

    $root = Split-Path -Parent $PSScriptRoot
    return [System.IO.Path]::GetFullPath((Join-Path $root $Path))
}

$resolvedConfigPath = Resolve-ProjectPath -Path $ConfigPath
if (-not (Test-Path $resolvedConfigPath)) {
    throw "Missing config file: $resolvedConfigPath"
}

$config = Get-Content -Path $resolvedConfigPath -Raw | ConvertFrom-Json
if ($null -eq $config) {
    throw "Config file is empty: $resolvedConfigPath"
}

$currentValue = $false
if ($config.PSObject.Properties['use12HourTime']) {
    $currentValue = [bool]$config.use12HourTime
}

$nextValue = $currentValue
if ($PSBoundParameters.ContainsKey('Use12HourTime') -and -not [string]::IsNullOrWhiteSpace($Use12HourTime)) {
    $normalizedValue = $Use12HourTime.Trim().ToLowerInvariant()
    if ($normalizedValue -eq 'true' -or $normalizedValue -eq '1' -or $normalizedValue -eq 'on') {
        $nextValue = $true
    } elseif ($normalizedValue -eq 'false' -or $normalizedValue -eq '0' -or $normalizedValue -eq 'off') {
        $nextValue = $false
    } else {
        throw "Invalid Use12HourTime value: $Use12HourTime"
    }
} elseif ($Toggle) {
    $nextValue = -not $currentValue
}

if ($config.PSObject.Properties['use12HourTime']) {
    $config.use12HourTime = $nextValue
} else {
    $config | Add-Member -NotePropertyName 'use12HourTime' -NotePropertyValue $nextValue
}

$json = $config | ConvertTo-Json -Depth 8
Set-Content -Path $resolvedConfigPath -Value $json -Encoding UTF8

Write-Host ("Changed use12HourTime from {0} to {1} in {2}" -f $currentValue.ToString().ToLowerInvariant(), $nextValue.ToString().ToLowerInvariant(), $resolvedConfigPath)
