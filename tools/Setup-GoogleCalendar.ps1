param(
    [string]$ConfigPath = '.\tools\GoogleCalendar.config.json'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

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

function Get-DefaultConfig {
    return [ordered]@{
        clientId = ''
        clientSecret = ''
        refreshToken = ''
        calendarIds = @('primary')
        timeZone = 'America/New_York'
        use12HourTime = $false
        lookAheadDays = 14
        maxResultsPerCalendar = 100
    }
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

    return [ordered]@{
        clientId = [string]$appConfig.clientId
        clientSecret = [string]$appConfig.clientSecret
        appConfigPath = $appConfigPath
    }
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

function Load-Config {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path $Path)) {
        return Get-DefaultConfig
    }

    $parsed = Get-Content -Path $Path -Raw | ConvertFrom-Json
    $config = Get-DefaultConfig

    foreach ($property in $parsed.PSObject.Properties) {
        $config[$property.Name] = $property.Value
    }

    if ($null -eq $config.calendarIds -or @($config.calendarIds).Count -eq 0) {
        $config.calendarIds = @('primary')
    }

    return $config
}

function Save-Config {
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [hashtable]$Config
    )

    $json = $Config | ConvertTo-Json -Depth 8
    Set-Content -Path $Path -Value $json -Encoding UTF8
}

function Get-EffectiveClientCredentials {
    param(
        [Parameter(Mandatory)]
        [hashtable]$Config,

        [Parameter(Mandatory)]
        [string]$ConfigFile
    )

    $clientId = Get-NormalizedCredentialValue -Value ([string]$Config.clientId)
    $clientSecret = Get-NormalizedCredentialValue -Value ([string]$Config.clientSecret)

    if (-not [string]::IsNullOrWhiteSpace($clientId) -and -not [string]::IsNullOrWhiteSpace($clientSecret)) {
        return [ordered]@{
            clientId = $clientId
            clientSecret = $clientSecret
            source = 'user-config'
        }
    }

    $appCredentials = Load-AppCredentials -ConfigFile $ConfigFile
    if ($null -ne $appCredentials) {
        return [ordered]@{
            clientId = (Get-NormalizedCredentialValue -Value ([string]$appCredentials.clientId))
            clientSecret = (Get-NormalizedCredentialValue -Value ([string]$appCredentials.clientSecret))
            source = 'app-config'
            appConfigPath = [string]$appCredentials.appConfigPath
        }
    }

    return $null
}

function Get-AccessToken {
    param(
        [Parameter(Mandatory)]
        [hashtable]$Config,

        [Parameter(Mandatory)]
        [string]$ConfigFile
    )

    $credentials = Get-EffectiveClientCredentials -Config $Config -ConfigFile $ConfigFile
    if ($null -eq $credentials) {
        throw 'No OAuth client credentials found. Add them to GoogleCalendar.app.json or enter them below.'
    }

    if ([string]::IsNullOrWhiteSpace([string]$Config.refreshToken)) {
        throw 'No refresh token found. Click Authorize Google first.'
    }

    $body = @{
        client_id = [string]$credentials.clientId
        client_secret = [string]$credentials.clientSecret
        refresh_token = [string]$Config.refreshToken
        grant_type = 'refresh_token'
    }

    $response = Invoke-RestMethod `
        -Method Post `
        -Uri 'https://oauth2.googleapis.com/token' `
        -Body $body `
        -ContentType 'application/x-www-form-urlencoded'

    if (-not $response.access_token) {
        throw 'Token response did not include access_token.'
    }

    return [string]$response.access_token
}

function Get-CalendarList {
    param(
        [Parameter(Mandatory)]
        [string]$AccessToken
    )

    $calendars = New-Object System.Collections.Generic.List[object]
    $pageToken = $null

    do {
        $queryParts = @('maxResults=250', 'minAccessRole=reader')
        if (-not [string]::IsNullOrWhiteSpace($pageToken)) {
            $queryParts += 'pageToken=' + [System.Uri]::EscapeDataString($pageToken)
        }

        $uri = 'https://www.googleapis.com/calendar/v3/users/me/calendarList?' + ($queryParts -join '&')
        $response = Invoke-RestMethod `
            -Method Get `
            -Uri $uri `
            -Headers @{ Authorization = "Bearer $AccessToken" }

        foreach ($item in @($response.items)) {
            $summaryOverride = $null
            if ($item.PSObject.Properties['summaryOverride']) {
                $summaryOverride = [string]$item.summaryOverride
            }

            $summary = $null
            if ($item.PSObject.Properties['summary']) {
                $summary = [string]$item.summary
            }

            $label = if (-not [string]::IsNullOrWhiteSpace($summaryOverride)) {
                $summaryOverride
            } elseif (-not [string]::IsNullOrWhiteSpace($summary)) {
                $summary
            } else {
                [string]$item.id
            }

            $isPrimary = $false
            if ($item.PSObject.Properties['primary']) {
                $isPrimary = [bool]$item.primary
            }

            $calendars.Add([ordered]@{
                id = [string]$item.id
                summary = $label
                primary = $isPrimary
            })
        }

        $pageToken = $null
        if ($response.PSObject.Properties['nextPageToken']) {
            $pageToken = [string]$response.nextPageToken
        }
    } while (-not [string]::IsNullOrWhiteSpace($pageToken))

    return @(
        $calendars |
        Sort-Object @{ Expression = { if ($_.primary) { 0 } else { 1 } } }, summary
    )
}

function New-Label {
    param(
        [string]$Text,
        [int]$X,
        [int]$Y,
        [int]$Width = 180
    )

    $label = New-Object System.Windows.Forms.Label
    $label.Text = $Text
    $label.Location = New-Object System.Drawing.Point($X, $Y)
    $label.Size = New-Object System.Drawing.Size($Width, 20)
    $label.ForeColor = [System.Drawing.Color]::FromArgb(230, 230, 230)
    $label.BackColor = [System.Drawing.Color]::Transparent
    return $label
}

function New-TextBox {
    param(
        [int]$X,
        [int]$Y,
        [int]$Width = 520,
        [string]$Text = '',
        [switch]$Multiline,
        [switch]$ReadOnly
    )

    $box = New-Object System.Windows.Forms.TextBox
    $box.Location = New-Object System.Drawing.Point($X, $Y)
    $box.Size = New-Object System.Drawing.Size($Width, $(if ($Multiline) { 58 } else { 24 }))
    $box.Text = $Text
    $box.Multiline = [bool]$Multiline
    $box.ReadOnly = [bool]$ReadOnly
    $box.BorderStyle = 'FixedSingle'
    $box.BackColor = [System.Drawing.Color]::FromArgb(28, 34, 43)
    $box.ForeColor = [System.Drawing.Color]::FromArgb(240, 240, 240)
    return $box
}

function New-Button {
    param(
        [string]$Text,
        [int]$X,
        [int]$Y,
        [int]$Width = 140
    )

    $button = New-Object System.Windows.Forms.Button
    $button.Text = $Text
    $button.Location = New-Object System.Drawing.Point($X, $Y)
    $button.Size = New-Object System.Drawing.Size($Width, 30)
    $button.FlatStyle = 'Flat'
    $button.BackColor = [System.Drawing.Color]::FromArgb(245, 192, 86)
    $button.ForeColor = [System.Drawing.Color]::FromArgb(23, 24, 24)
    return $button
}

$resolvedConfigPath = Resolve-ProjectPath -Path $ConfigPath
$config = Load-Config -Path $resolvedConfigPath
$appCredentials = Load-AppCredentials -ConfigFile $resolvedConfigPath
$script:CurrentConfig = $config

$form = New-Object System.Windows.Forms.Form
$form.Text = 'Google Calendar Rainmeter Setup'
$form.StartPosition = 'CenterScreen'
$form.Size = New-Object System.Drawing.Size(720, 640)
$form.BackColor = [System.Drawing.Color]::FromArgb(18, 23, 30)
$form.ForeColor = [System.Drawing.Color]::White
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false

$header = New-Label -Text 'Configure credentials, calendars, and OAuth setup' -X 20 -Y 18 -Width 600
$header.Font = New-Object System.Drawing.Font('Segoe UI', 12, [System.Drawing.FontStyle]::Bold)
$form.Controls.Add($header)

$clientIdLabel = New-Label -Text 'Client ID' -X 20 -Y 58
$clientIdBox = New-TextBox -X 20 -Y 80 -Text ([string]$config.clientId)
$form.Controls.Add($clientIdLabel)
$form.Controls.Add($clientIdBox)

$clientSecretLabel = New-Label -Text 'Client Secret' -X 20 -Y 116
$clientSecretBox = New-TextBox -X 20 -Y 138 -Text ([string]$config.clientSecret)
$form.Controls.Add($clientSecretLabel)
$form.Controls.Add($clientSecretBox)

$credentialsStatusLabel = New-Label -Text 'OAuth App Source' -X 420 -Y 58 -Width 240
$credentialsStatusText = if ($null -ne $appCredentials) {
    "Bundled app config found: $($appCredentials.appConfigPath)"
} else {
    'No bundled app config found. Enter credentials below or add GoogleCalendar.app.json.'
}
$credentialsStatusBox = New-TextBox -X 420 -Y 80 -Width 260 -Text $credentialsStatusText -Multiline -ReadOnly
$form.Controls.Add($credentialsStatusLabel)
$form.Controls.Add($credentialsStatusBox)

$calendarPickerLabel = New-Label -Text 'Calendars to Sync' -X 20 -Y 174 -Width 220
$calendarPicker = New-Object System.Windows.Forms.CheckedListBox
$calendarPicker.Location = New-Object System.Drawing.Point(20, 196)
$calendarPicker.Size = New-Object System.Drawing.Size(660, 94)
$calendarPicker.CheckOnClick = $true
$calendarPicker.BorderStyle = 'FixedSingle'
$calendarPicker.BackColor = [System.Drawing.Color]::FromArgb(28, 34, 43)
$calendarPicker.ForeColor = [System.Drawing.Color]::FromArgb(240, 240, 240)
$form.Controls.Add($calendarPickerLabel)
$form.Controls.Add($calendarPicker)

$timeZoneLabel = New-Label -Text 'Time Zone' -X 20 -Y 306
$timeZoneBox = New-TextBox -X 20 -Y 328 -Width 240 -Text ([string]$config.timeZone)
$form.Controls.Add($timeZoneLabel)
$form.Controls.Add($timeZoneBox)

$lookAheadLabel = New-Label -Text 'Look Ahead Days' -X 280 -Y 306
$lookAheadBox = New-TextBox -X 280 -Y 328 -Width 120 -Text ([string]$config.lookAheadDays)
$form.Controls.Add($lookAheadLabel)
$form.Controls.Add($lookAheadBox)

$maxResultsLabel = New-Label -Text 'Max Results / Calendar' -X 420 -Y 306
$maxResultsBox = New-TextBox -X 420 -Y 328 -Width 120 -Text ([string]$config.maxResultsPerCalendar)
$form.Controls.Add($maxResultsLabel)
$form.Controls.Add($maxResultsBox)

$use12HourCheckbox = New-Object System.Windows.Forms.CheckBox
$use12HourCheckbox.Text = 'Display times in 12-hour format'
$use12HourCheckbox.Location = New-Object System.Drawing.Point(20, 358)
$use12HourCheckbox.Size = New-Object System.Drawing.Size(240, 24)
$use12HourCheckbox.Checked = [bool]$config.use12HourTime
$use12HourCheckbox.ForeColor = [System.Drawing.Color]::FromArgb(230, 230, 230)
$use12HourCheckbox.BackColor = [System.Drawing.Color]::Transparent
$form.Controls.Add($use12HourCheckbox)

$refreshTokenLabel = New-Label -Text 'Refresh Token' -X 20 -Y 394
$refreshTokenBox = New-TextBox -X 20 -Y 416 -Text ([string]$config.refreshToken) -Multiline -ReadOnly
$form.Controls.Add($refreshTokenLabel)
$form.Controls.Add($refreshTokenBox)

$statusLabel = New-Label -Text 'Status' -X 20 -Y 488
$statusBox = New-TextBox -X 20 -Y 510 -Width 660 -Text 'Ready.' -ReadOnly
$form.Controls.Add($statusLabel)
$form.Controls.Add($statusBox)

$saveButton = New-Button -Text 'Save Config' -X 20 -Y 572
$authButton = New-Button -Text 'Authorize Google' -X 180 -Y 572 -Width 160
$loadCalendarsButton = New-Button -Text 'Load Calendars' -X 360 -Y 572 -Width 140
$openConfigButton = New-Button -Text 'Open Config Folder' -X 520 -Y 572 -Width 160

$form.Controls.Add($saveButton)
$form.Controls.Add($authButton)
$form.Controls.Add($loadCalendarsButton)
$form.Controls.Add($openConfigButton)

$script:LoadedCalendars = @()

function Update-CalendarPicker {
    param(
        [object[]]$Calendars
    )

    $script:LoadedCalendars = @($Calendars)
    $selectedIds = @([string[]]@($script:CurrentConfig.calendarIds))

    $calendarPicker.Items.Clear()
    foreach ($calendar in $script:LoadedCalendars) {
        $label = [string]$calendar.summary
        if ($calendar.primary) {
            $label = "$label (Primary)"
        }

        $index = $calendarPicker.Items.Add($label)
        if ($selectedIds -contains [string]$calendar.id) {
            $calendarPicker.SetItemChecked($index, $true)
        }
    }
}

function Get-ConfigFromForm {
    $calendarIds = New-Object System.Collections.Generic.List[string]

    foreach ($index in $calendarPicker.CheckedIndices) {
        if ($index -lt $script:LoadedCalendars.Count) {
            $calendarIds.Add([string]$script:LoadedCalendars[$index].id)
        }
    }

    if ($calendarIds.Count -eq 0) {
        $calendarIds = @('primary')
    }

    return [ordered]@{
        clientId = $clientIdBox.Text.Trim()
        clientSecret = $clientSecretBox.Text.Trim()
        refreshToken = $refreshTokenBox.Text.Trim()
        calendarIds = $calendarIds
        timeZone = $timeZoneBox.Text.Trim()
        use12HourTime = [bool]$use12HourCheckbox.Checked
        lookAheadDays = [int]$lookAheadBox.Text
        maxResultsPerCalendar = [int]$maxResultsBox.Text
    }
}

function Load-CalendarsIntoPicker {
    try {
        $currentConfig = Get-ConfigFromForm
        $accessToken = Get-AccessToken -Config $currentConfig -ConfigFile $resolvedConfigPath
        $calendarList = Get-CalendarList -AccessToken $accessToken
        Update-CalendarPicker -Calendars $calendarList
        $statusBox.Text = "Loaded $($calendarList.Count) calendars from Google."
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Calendar Load Failed', 'OK', 'Error') | Out-Null
        $statusBox.Text = 'Calendar load failed.'
    }
}

$saveButton.Add_Click({
    try {
        $currentConfig = Get-ConfigFromForm
        $script:CurrentConfig = $currentConfig
        Save-Config -Path $resolvedConfigPath -Config $currentConfig
        $statusBox.Text = "Saved config to $resolvedConfigPath"
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Save Failed', 'OK', 'Error') | Out-Null
    }
})

$authButton.Add_Click({
    try {
        $currentConfig = Get-ConfigFromForm
        $script:CurrentConfig = $currentConfig
        Save-Config -Path $resolvedConfigPath -Config $currentConfig
        $statusBox.Text = 'Launching browser authorization flow...'

        $authOutput = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'Get-GoogleRefreshToken.ps1') -ConfigPath $resolvedConfigPath 2>&1
        if ($LASTEXITCODE -ne 0) {
            $authText = ($authOutput | ForEach-Object { [string]$_ }) -join [Environment]::NewLine
            if ([string]::IsNullOrWhiteSpace($authText)) {
                throw "Authorization helper exited with code $LASTEXITCODE."
            }

            throw "Authorization helper exited with code $LASTEXITCODE.`r`n`r`n$authText"
        }

        $updatedConfig = Load-Config -Path $resolvedConfigPath
        if ([string]::IsNullOrWhiteSpace([string]$updatedConfig.refreshToken)) {
            throw 'Authorization completed without saving a refresh token.'
        }

        $script:CurrentConfig = $updatedConfig
        $refreshTokenBox.Text = [string]$updatedConfig.refreshToken
        $statusBox.Text = 'Authorization finished and refresh token saved.'
        Load-CalendarsIntoPicker
    }
    catch {
        $statusBox.Text = 'Authorization failed.'
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Authorization Failed', 'OK', 'Error') | Out-Null
    }
})

$loadCalendarsButton.Add_Click({
    Load-CalendarsIntoPicker
})

$openConfigButton.Add_Click({
    Start-Process explorer.exe "/select,$resolvedConfigPath" | Out-Null
})

if (-not [string]::IsNullOrWhiteSpace([string]$script:CurrentConfig.refreshToken)) {
    try {
        Load-CalendarsIntoPicker
    }
    catch {
    }
}

[void]$form.ShowDialog()
