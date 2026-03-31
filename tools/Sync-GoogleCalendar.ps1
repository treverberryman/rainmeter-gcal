param(
    [ValidateSet('Mock', 'Google')]
    [string]$Mode = 'Mock',

    [string]$OutputPath = '.\@Resources\Data\CalendarCache.lua',

    [string]$ConfigPath = '.\tools\GoogleCalendar.config.json'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-StringValue {
    param(
        [Parameter(Mandatory)]
        [psobject]$Object,

        [Parameter(Mandatory)]
        [string]$PropertyName,

        [switch]$Required
    )

    $property = $Object.PSObject.Properties[$PropertyName]

    if ($null -eq $property) {
        if ($Required) {
            throw "Missing required config property '$PropertyName'."
        }

        return $null
    }

    $value = [string]$property.Value
    if ($Required -and [string]::IsNullOrWhiteSpace($value)) {
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
        clientId = Get-StringValue -Object $appConfig -PropertyName 'clientId' -Required
        clientSecret = Get-StringValue -Object $appConfig -PropertyName 'clientSecret' -Required
        appConfigPath = $appConfigPath
    }
}

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

function New-EventRecord {
    param(
        [Parameter(Mandatory)]
        [datetime]$Start,

        [Parameter(Mandatory)]
        [string]$Title,

        [Parameter(Mandatory)]
        [string]$Meta,

        [string]$DurationLabel,

        [string]$TimeLabel,

        [string]$SortTime
    )

    if (-not $TimeLabel) {
        $TimeLabel = $Start.ToString('ddd HH:mm').ToUpperInvariant()
    }

    if (-not $SortTime) {
        $SortTime = $Start.ToString('HH:mm')
    }

    return [ordered]@{
        year = $Start.Year
        month = $Start.Month
        day = $Start.Day
        sortTime = $SortTime
        timeLabel = $TimeLabel
        title = $Title
        durationLabel = $DurationLabel
        meta = $Meta
    }
}

function Get-MockEvents {
    $today = Get-Date

    return @(
        (New-EventRecord -Start $today.Date.AddHours(8).AddMinutes(30) -Title 'Standup and Inbox Sweep' -Meta 'Studio A - 20 min' -DurationLabel '08:30 - 08:50' -TimeLabel '08:30')
        (New-EventRecord -Start $today.Date.AddHours(10) -Title 'Product Review with Design' -Meta 'Meet - 45 min' -DurationLabel '10:00 - 10:45' -TimeLabel '10:00')
        (New-EventRecord -Start $today.Date.AddHours(13) -Title 'Calendar Skin Prototype Block' -Meta 'Focus - 2 hr' -DurationLabel '13:00 - 15:00' -TimeLabel '13:00')
        (New-EventRecord -Start $today.Date.AddDays(1).AddHours(9).AddMinutes(15) -Title 'Weekly Planning' -Meta 'Conference - 1 hr' -DurationLabel '09:15 - 10:15')
        (New-EventRecord -Start $today.Date.AddDays(1).AddHours(14) -Title 'Coffee with Contractor' -Meta 'Offsite - 45 min' -DurationLabel '14:00 - 14:45')
        (New-EventRecord -Start $today.Date.AddDays(2) -Title 'Quarterly Planning Deadline' -Meta 'All-day milestone' -DurationLabel 'ALL DAY' -TimeLabel 'ALL DAY' -SortTime '00:00')
    )
}

function ConvertTo-LuaString {
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [object]$Value
    )

    if ($null -eq $Value) {
        return '""'
    }

    $text = [string]$Value
    $text = $text.Replace('\', '\\').Replace('"', '\"')
    return '"' + $text + '"'
}

function Remove-UnsupportedUiGlyphs {
    param(
        [AllowNull()]
        [string]$Text
    )

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return $Text
    }

    $cleaned = [System.Text.RegularExpressions.Regex]::Replace($Text, '[^\u0000-\u007F]+', ' ')
    $cleaned = [System.Text.RegularExpressions.Regex]::Replace($cleaned, '\s{2,}', ' ').Trim()

    return $cleaned
}

function Write-LuaCache {
    param(
        [Parameter(Mandatory)]
        [object[]]$Events,

        [Parameter(Mandatory)]
        [string]$Source,

        [Parameter(Mandatory)]
        [string]$Path
    )

    $generatedAt = Get-Date -Format 'yyyy-MM-dd HH:mm'
    $lines = @(
        'return {'
        "  source = $(ConvertTo-LuaString $Source),"
        "  generatedAt = $(ConvertTo-LuaString $generatedAt),"
        '  events = {'
    )

    foreach ($event in $Events) {
        $lines += '    {'
        $lines += "      year = $($event.year),"
        $lines += "      month = $($event.month),"
        $lines += "      day = $($event.day),"
        $lines += "      sortTime = $(ConvertTo-LuaString $event.sortTime),"
        $lines += "      timeLabel = $(ConvertTo-LuaString $event.timeLabel),"
        $lines += "      title = $(ConvertTo-LuaString $event.title),"
        $lines += "      durationLabel = $(ConvertTo-LuaString $event.durationLabel),"
        $lines += "      meta = $(ConvertTo-LuaString $event.meta)"
        $lines += '    },'
    }

    $lines += '  }'
    $lines += '}'

    $directory = Split-Path -Parent $Path
    if (-not (Test-Path $directory)) {
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
    }

    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, ($lines -join [Environment]::NewLine), $utf8NoBom)
}

function Get-Config {
    param(
        [Parameter(Mandatory)]
        [string]$ConfigFile
    )

    if (-not (Test-Path $ConfigFile)) {
        throw "Missing config file: $ConfigFile"
    }

    $config = Get-Content -Path $ConfigFile -Raw | ConvertFrom-Json

    if ($null -eq $config) {
        throw "Config file is empty: $ConfigFile"
    }

    $calendarIds = @()
    if ($config.PSObject.Properties['calendarIds']) {
        $calendarIds = @($config.calendarIds | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    }

    if ($calendarIds.Count -eq 0) {
        $calendarIds = @('primary')
    }

    $lookAheadDays = 14
    if ($config.PSObject.Properties['lookAheadDays']) {
        $lookAheadDays = [int]$config.lookAheadDays
    }

    $use12HourTime = $false
    if ($config.PSObject.Properties['use12HourTime']) {
        $use12HourTime = [bool]$config.use12HourTime
    }

    $maxResultsPerCalendar = 100
    if ($config.PSObject.Properties['maxResultsPerCalendar']) {
        $maxResultsPerCalendar = [int]$config.maxResultsPerCalendar
    }

    $clientId = Get-NormalizedCredentialValue -Value (Get-StringValue -Object $config -PropertyName 'clientId')
    $clientSecret = Get-NormalizedCredentialValue -Value (Get-StringValue -Object $config -PropertyName 'clientSecret')

    if ([string]::IsNullOrWhiteSpace($clientId) -or [string]::IsNullOrWhiteSpace($clientSecret)) {
        $appCredentials = Load-AppCredentials -ConfigFile $ConfigFile
        if ($null -eq $appCredentials) {
            throw "No OAuth client credentials found. Add clientId/clientSecret to GoogleCalendar.app.json or enter them in setup."
        }

        $clientId = Get-NormalizedCredentialValue -Value ([string]$appCredentials.clientId)
        $clientSecret = Get-NormalizedCredentialValue -Value ([string]$appCredentials.clientSecret)
    }

    return [ordered]@{
        clientId = $clientId
        clientSecret = $clientSecret
        refreshToken = Get-StringValue -Object $config -PropertyName 'refreshToken' -Required
        calendarIds = $calendarIds
        timeZone = (Get-StringValue -Object $config -PropertyName 'timeZone')
        use12HourTime = $use12HourTime
        lookAheadDays = $lookAheadDays
        maxResultsPerCalendar = $maxResultsPerCalendar
    }
}

function Get-AccessToken {
    param(
        [Parameter(Mandatory)]
        [hashtable]$Config
    )

    $body = @{
        client_id = $Config.clientId
        client_secret = $Config.clientSecret
        refresh_token = $Config.refreshToken
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

function ConvertTo-QueryString {
    param(
        [Parameter(Mandatory)]
        [hashtable]$Parameters
    )

    $pairs = foreach ($entry in $Parameters.GetEnumerator()) {
        if ($null -eq $entry.Value -or [string]::IsNullOrWhiteSpace([string]$entry.Value)) {
            continue
        }

        '{0}={1}' -f `
            [System.Uri]::EscapeDataString([string]$entry.Key), `
            [System.Uri]::EscapeDataString([string]$entry.Value)
    }

    return ($pairs -join '&')
}

function Format-ClockText {
    param(
        [Parameter(Mandatory)]
        [datetime]$Time,

        [switch]$Use12HourTime
    )

    if ($Use12HourTime) {
        return $Time.ToString('h:mm')
    }

    return $Time.ToString('HH:mm')
}

function Get-TimeRangeLabel {
    param(
        [AllowNull()]
        [datetime]$Start,

        [AllowNull()]
        [datetime]$End,

        [switch]$Use12HourTime,

        [switch]$AllDay
    )

    if ($AllDay) {
        return 'ALL DAY'
    }

    if ($null -eq $Start -or $null -eq $End) {
        return $null
    }

    return '{0} - {1}' -f `
        (Format-ClockText -Time $Start -Use12HourTime:$Use12HourTime), `
        (Format-ClockText -Time $End -Use12HourTime:$Use12HourTime)
}

function Get-TimeLabel {
    param(
        [Parameter(Mandatory)]
        [datetime]$Start,

        [switch]$Use12HourTime,

        [switch]$AllDay
    )

    if ($AllDay) {
        return '{0} ALL DAY' -f $Start.ToString('ddd').ToUpperInvariant()
    }

    return '{0} {1}' -f $Start.ToString('ddd').ToUpperInvariant(), (Format-ClockText -Time $Start -Use12HourTime:$Use12HourTime)
}

function Convert-GoogleEvent {
    param(
        [Parameter(Mandatory)]
        [psobject]$Event,

        [Parameter(Mandatory)]
        [string]$CalendarLabel,

        [switch]$Use12HourTime
    )

    $status = $null
    if ($Event.PSObject.Properties['status']) {
        $status = [string]$Event.status
    }

    if ($status -eq 'cancelled') {
        return $null
    }

    $isAllDay = $false
    $start = $null
    $end = $null

    $startDate = $null
    $startDateTime = $null
    $endDate = $null
    $endDateTime = $null

    if ($Event.PSObject.Properties['start'] -and $Event.start -and $Event.start.PSObject.Properties['date']) {
        $startDate = [string]$Event.start.date
    }

    if ($Event.PSObject.Properties['start'] -and $Event.start -and $Event.start.PSObject.Properties['dateTime']) {
        $startDateTime = [string]$Event.start.dateTime
    }

    if ($Event.PSObject.Properties['end'] -and $Event.end -and $Event.end.PSObject.Properties['date']) {
        $endDate = [string]$Event.end.date
    }

    if ($Event.PSObject.Properties['end'] -and $Event.end -and $Event.end.PSObject.Properties['dateTime']) {
        $endDateTime = [string]$Event.end.dateTime
    }

    if (-not [string]::IsNullOrWhiteSpace($startDate)) {
        $isAllDay = $true
        $start = [datetime]::Parse($startDate)
        if (-not [string]::IsNullOrWhiteSpace($endDate)) {
            $end = [datetime]::Parse($endDate)
        }
    } elseif (-not [string]::IsNullOrWhiteSpace($startDateTime)) {
        $start = [datetimeoffset]::Parse($startDateTime).LocalDateTime
        if (-not [string]::IsNullOrWhiteSpace($endDateTime)) {
            $end = [datetimeoffset]::Parse($endDateTime).LocalDateTime
        }
    } else {
        return $null
    }

    $metaParts = New-Object System.Collections.Generic.List[string]
    $metaParts.Add($CalendarLabel)

    if ($Event.PSObject.Properties['location']) {
        $location = [string]$Event.location
        if (-not [string]::IsNullOrWhiteSpace($location)) {
            $metaParts.Add($location)
        }
    }

    $durationLabel = Get-TimeRangeLabel -Start $start -End $end -Use12HourTime:$Use12HourTime -AllDay:$isAllDay
    if ($durationLabel) {
        $metaParts.Add($durationLabel)
    }

    $summary = $null
    if ($Event.PSObject.Properties['summary']) {
        $summary = [string]$Event.summary
    }

    $summary = Remove-UnsupportedUiGlyphs -Text $summary
    $metaText = Remove-UnsupportedUiGlyphs -Text ($metaParts -join ' - ')

    return [ordered]@{
        year = $start.Year
        month = $start.Month
        day = $start.Day
        sortTime = $(if ($isAllDay) { '00:00' } else { $start.ToString('HH:mm') })
        timeLabel = Get-TimeLabel -Start $start -Use12HourTime:$Use12HourTime -AllDay:$isAllDay
        title = $(if ([string]::IsNullOrWhiteSpace($summary)) { '(Untitled event)' } else { $summary })
        durationLabel = $durationLabel
        meta = $metaText
    }
}

function Get-CalendarEventsPage {
    param(
        [Parameter(Mandatory)]
        [string]$AccessToken,

        [Parameter(Mandatory)]
        [string]$CalendarId,

        [Parameter(Mandatory)]
        [datetimeoffset]$TimeMin,

        [Parameter(Mandatory)]
        [datetimeoffset]$TimeMax,

        [Parameter(Mandatory)]
        [int]$MaxResults,

        [string]$TimeZone,

        [string]$PageToken
    )

    $query = @{
        singleEvents = 'true'
        orderBy = 'startTime'
        timeMin = $TimeMin.ToString('o')
        timeMax = $TimeMax.ToString('o')
        maxResults = [string]$MaxResults
        pageToken = $PageToken
        timeZone = $TimeZone
    }

    $queryString = ConvertTo-QueryString -Parameters $query
    $encodedCalendarId = [System.Uri]::EscapeDataString($CalendarId)
    $uri = "https://www.googleapis.com/calendar/v3/calendars/$encodedCalendarId/events?$queryString"

    return Invoke-RestMethod `
        -Method Get `
        -Uri $uri `
        -Headers @{ Authorization = "Bearer $AccessToken" }
}

function Get-CalendarList {
    param(
        [Parameter(Mandatory)]
        [string]$AccessToken
    )

    $calendars = New-Object System.Collections.Generic.List[object]
    $pageToken = $null

    do {
        $query = @{
            maxResults = '250'
            minAccessRole = 'reader'
            pageToken = $pageToken
        }

        $queryString = ConvertTo-QueryString -Parameters $query
        $uri = "https://www.googleapis.com/calendar/v3/users/me/calendarList?$queryString"
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

function Get-GoogleCalendarEvents {
    param(
        [Parameter(Mandatory)]
        [string]$ConfigFile
    )

    $config = Get-Config -ConfigFile $ConfigFile
    $accessToken = Get-AccessToken -Config $config

    $calendarList = Get-CalendarList -AccessToken $accessToken
    $calendarLookup = @{}
    foreach ($calendar in $calendarList) {
        $calendarLookup[[string]$calendar.id] = [string]$calendar.summary
    }

    $timeMin = [datetimeoffset]::Now.AddDays(-1)
    $timeMax = [datetimeoffset]::Now.AddDays($config.lookAheadDays)
    $events = New-Object System.Collections.Generic.List[object]

    foreach ($calendarId in $config.calendarIds) {
        $pageToken = $null

        do {
            $response = Get-CalendarEventsPage `
                -AccessToken $accessToken `
                -CalendarId $calendarId `
                -TimeMin $timeMin `
                -TimeMax $timeMax `
                -MaxResults $config.maxResultsPerCalendar `
                -TimeZone $config.timeZone `
                -PageToken $pageToken

            foreach ($item in @($response.items)) {
                $calendarLabel = $calendarId
                if ($calendarLookup.ContainsKey([string]$calendarId)) {
                    $calendarLabel = [string]$calendarLookup[[string]$calendarId]
                }

                $converted = Convert-GoogleEvent -Event $item -CalendarLabel $calendarLabel -Use12HourTime:$config.use12HourTime
                if ($null -ne $converted) {
                    $events.Add($converted)
                }
            }

            $pageToken = $null
            if ($response.PSObject.Properties['nextPageToken']) {
                $pageToken = [string]$response.nextPageToken
            }
        } while (-not [string]::IsNullOrWhiteSpace($pageToken))
    }

    return @($events | Sort-Object year, month, day, sortTime, title)
}

$resolvedOutputPath = Resolve-ProjectPath -Path $OutputPath
$resolvedConfigPath = Resolve-ProjectPath -Path $ConfigPath

if ($Mode -eq 'Mock') {
    $events = Get-MockEvents
    Write-LuaCache -Events $events -Source 'mock-sync' -Path $resolvedOutputPath
    Write-Host ("Wrote mock cache to {0} at {1}" -f $resolvedOutputPath, (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))
    exit 0
}

$googleEvents = Get-GoogleCalendarEvents -ConfigFile $resolvedConfigPath
Write-LuaCache -Events $googleEvents -Source 'google-calendar' -Path $resolvedOutputPath
Write-Host ("Wrote Google Calendar cache to {0} at {1} with {2} events" -f $resolvedOutputPath, (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $googleEvents.Count)
