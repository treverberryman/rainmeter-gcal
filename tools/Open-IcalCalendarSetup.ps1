param(
    [Parameter(Mandatory = $true)]
    [string]$ConfigPath,
    [Parameter(Mandatory = $true)]
    [string]$ExamplePath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $ConfigPath)) {
    if (-not (Test-Path -LiteralPath $ExamplePath)) {
        throw "Missing iCal configuration template: $ExamplePath"
    }

    Copy-Item -LiteralPath $ExamplePath -Destination $ConfigPath -ErrorAction Stop
}

Start-Process -FilePath 'notepad.exe' -ArgumentList @($ConfigPath)
