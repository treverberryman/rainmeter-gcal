param(
    [string]$ConfigPath = '.\tools\GoogleCalendar.config.json',
    [int]$Port = 53682,
    [string]$Scope = 'https://www.googleapis.com/auth/calendar.readonly'
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

function Get-StringValue {
    param(
        [Parameter(Mandatory)]
        [psobject]$Object,

        [Parameter(Mandatory)]
        [string]$PropertyName
    )

    $property = $Object.PSObject.Properties[$PropertyName]
    if ($null -eq $property) {
        throw "Missing required config property '$PropertyName'."
    }

    $value = [string]$property.Value
    if ([string]::IsNullOrWhiteSpace($value)) {
        throw "Config property '$PropertyName' cannot be empty."
    }

    return $value.Trim()
}

function Get-NormalizedCredentialValue {
    param(
        [AllowNull()]
        [string]$Value
    )

    $text = [string]$Value
    if ([string]::IsNullOrWhiteSpace($text)) {
        return ''
    }

    $text = $text.Trim()
    if ($text -in @('YOUR_DESKTOP_APP_CLIENT_ID', 'YOUR_DESKTOP_APP_CLIENT_SECRET')) {
        return ''
    }

    return $text
}

function Load-AppCredentials {
    param(
        [Parameter(Mandatory)]
        [string]$ConfigFile
    )

    $configDirectory = Split-Path -Parent $ConfigFile
    $appConfigPath = Join-Path $configDirectory 'GoogleCalendar.app.json'

    if (-not (Test-Path $appConfigPath)) {
        return $null
    }

    $appConfig = Get-Content -Path $appConfigPath -Raw | ConvertFrom-Json
    if ($null -eq $appConfig) {
        throw "App credentials file is empty: $appConfigPath"
    }

    return @{
        clientId = Get-StringValue -Object $appConfig -PropertyName 'clientId'
        clientSecret = Get-StringValue -Object $appConfig -PropertyName 'clientSecret'
        appConfigPath = $appConfigPath
    }
}

function Get-EffectiveClientCredentials {
    param(
        [Parameter(Mandatory)]
        [psobject]$Config,

        [Parameter(Mandatory)]
        [string]$ConfigFile
    )

    $clientId = $null
    $clientSecret = $null

    $clientIdProperty = $Config.PSObject.Properties['clientId']
    if ($null -ne $clientIdProperty) {
        $clientId = [string]$clientIdProperty.Value
    }

    $clientSecretProperty = $Config.PSObject.Properties['clientSecret']
    if ($null -ne $clientSecretProperty) {
        $clientSecret = [string]$clientSecretProperty.Value
    }

    $clientId = Get-NormalizedCredentialValue -Value $clientId
    $clientSecret = Get-NormalizedCredentialValue -Value $clientSecret

    if (-not [string]::IsNullOrWhiteSpace($clientId) -and -not [string]::IsNullOrWhiteSpace($clientSecret)) {
        return @{
            clientId = $clientId.Trim()
            clientSecret = $clientSecret.Trim()
            source = 'user-config'
        }
    }

    $appCredentials = Load-AppCredentials -ConfigFile $ConfigFile
    if ($null -ne $appCredentials) {
        return @{
            clientId = (Get-NormalizedCredentialValue -Value ([string]$appCredentials.clientId))
            clientSecret = (Get-NormalizedCredentialValue -Value ([string]$appCredentials.clientSecret))
            source = 'app-config'
        }
    }

    throw 'No OAuth client credentials found. Add clientId/clientSecret to GoogleCalendar.app.json or enter them in setup.'
}

function Get-CodeVerifier {
    $bytes = New-Object byte[] 64
    [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
    $base64 = [Convert]::ToBase64String($bytes).TrimEnd('=').Replace('+', '-').Replace('/', '_')
    if ($base64.Length -gt 128) {
        return $base64.Substring(0, 128)
    }

    return $base64
}

function Get-CodeChallenge {
    param(
        [Parameter(Mandatory)]
        [string]$Verifier
    )

    $bytes = [System.Text.Encoding]::ASCII.GetBytes($Verifier)
    $hash = [System.Security.Cryptography.SHA256]::Create().ComputeHash($bytes)
    return [Convert]::ToBase64String($hash).TrimEnd('=').Replace('+', '-').Replace('/', '_')
}

function ConvertTo-QueryString {
    param(
        [Parameter(Mandatory)]
        [hashtable]$Parameters
    )

    $pairs = foreach ($entry in $Parameters.GetEnumerator()) {
        '{0}={1}' -f `
            [System.Uri]::EscapeDataString([string]$entry.Key), `
            [System.Uri]::EscapeDataString([string]$entry.Value)
    }

    return ($pairs -join '&')
}

function Write-SuccessResponse {
    param(
        [Parameter(Mandatory)]
        [System.Net.HttpListenerContext]$Context
    )

    $html = @'
<html>
<head><title>Google Calendar Auth Complete</title></head>
<body style="font-family:Segoe UI, sans-serif; background:#111827; color:#f3f4f6; padding:32px;">
  <h2>Authorization complete</h2>
  <p>You can close this browser window and return to Rainmeter.</p>
</body>
</html>
'@

    $buffer = [System.Text.Encoding]::UTF8.GetBytes($html)
    $Context.Response.ContentType = 'text/html; charset=utf-8'
    $Context.Response.ContentLength64 = $buffer.Length
    $Context.Response.OutputStream.Write($buffer, 0, $buffer.Length)
    $Context.Response.OutputStream.Close()
}

function Update-ConfigWithRefreshToken {
    param(
        [Parameter(Mandatory)]
        [string]$ConfigFile,

        [Parameter(Mandatory)]
        [string]$RefreshToken
    )

    $config = Get-Content -Path $ConfigFile -Raw | ConvertFrom-Json

    if ($config.PSObject.Properties['refreshToken']) {
        $config.refreshToken = $RefreshToken
    } else {
        $config | Add-Member -NotePropertyName refreshToken -NotePropertyValue $RefreshToken
    }

    $json = $config | ConvertTo-Json -Depth 8
    Set-Content -Path $ConfigFile -Value $json -Encoding UTF8
}

$resolvedConfigPath = Resolve-ProjectPath -Path $ConfigPath
if (-not (Test-Path $resolvedConfigPath)) {
    throw "Missing config file: $resolvedConfigPath"
}

$config = Get-Content -Path $resolvedConfigPath -Raw | ConvertFrom-Json
$credentials = Get-EffectiveClientCredentials -Config $config -ConfigFile $resolvedConfigPath
$clientId = [string]$credentials.clientId
$clientSecret = [string]$credentials.clientSecret
$redirectUri = "http://127.0.0.1:$Port/"
$codeVerifier = Get-CodeVerifier
$codeChallenge = Get-CodeChallenge -Verifier $codeVerifier
$state = [guid]::NewGuid().ToString('N')

$listener = [System.Net.HttpListener]::new()
$listener.Prefixes.Add($redirectUri)
$listener.Start()

try {
    $query = @{
        client_id = $clientId
        redirect_uri = $redirectUri
        response_type = 'code'
        scope = $Scope
        access_type = 'offline'
        prompt = 'consent'
        code_challenge = $codeChallenge
        code_challenge_method = 'S256'
        state = $state
    }

    $authorizationUrl = 'https://accounts.google.com/o/oauth2/v2/auth?' + (ConvertTo-QueryString -Parameters $query)
    Start-Process $authorizationUrl | Out-Null
    Write-Host "Opened browser for Google authorization."
    Write-Host "Waiting for redirect on $redirectUri"

    $context = $listener.GetContext()
    $request = $context.Request
    $code = $request.QueryString['code']
    $returnedState = $request.QueryString['state']
    $oauthError = $request.QueryString['error']

    Write-SuccessResponse -Context $context

    if ($oauthError) {
        throw "Authorization failed: $oauthError"
    }

    if ($returnedState -ne $state) {
        throw 'State mismatch in OAuth response.'
    }

    if ([string]::IsNullOrWhiteSpace($code)) {
        throw 'Authorization response did not include a code.'
    }

    $tokenBody = @{
        client_id = $clientId
        client_secret = $clientSecret
        code = $code
        code_verifier = $codeVerifier
        grant_type = 'authorization_code'
        redirect_uri = $redirectUri
    }

    $tokenResponse = Invoke-RestMethod `
        -Method Post `
        -Uri 'https://oauth2.googleapis.com/token' `
        -Body $tokenBody `
        -ContentType 'application/x-www-form-urlencoded'

    if (-not $tokenResponse.refresh_token) {
        throw 'Token response did not include refresh_token. Re-run after removing prior consent or ensure prompt=consent is honored.'
    }

    Update-ConfigWithRefreshToken -ConfigFile $resolvedConfigPath -RefreshToken ([string]$tokenResponse.refresh_token)
    Write-Host "Saved refresh token to $resolvedConfigPath"
}
finally {
    if ($listener.IsListening) {
        $listener.Stop()
    }

    $listener.Close()
}
