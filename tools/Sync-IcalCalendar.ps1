param(
    [string]$OutputPath = '.\@Resources\Data\CalendarCache.lua',
    [string]$ConfigPath = '.\tools\IcalCalendar.config.json'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Resolve-ProjectPath([string]$Path) {
    if ([System.IO.Path]::IsPathRooted($Path)) { return [System.IO.Path]::GetFullPath($Path) }
    return [System.IO.Path]::GetFullPath((Join-Path (Split-Path -Parent $PSScriptRoot) $Path))
}

function Convert-HexColor([string]$Color, [string]$CalendarName) {
    if ([string]::IsNullOrWhiteSpace($Color)) { return '' }
    $value = $Color.Trim()
    if ($value -notmatch '^#?([0-9a-fA-F]{6})([0-9a-fA-F]{2})?$') {
        throw "Invalid color for calendar '$CalendarName'. Use #RRGGBB or #RRGGBBAA."
    }
    $red = [Convert]::ToInt32($matches[1].Substring(0, 2), 16)
    $green = [Convert]::ToInt32($matches[1].Substring(2, 2), 16)
    $blue = [Convert]::ToInt32($matches[1].Substring(4, 2), 16)
    $alpha = if ($matches[2]) { [Convert]::ToInt32($matches[2], 16) } else { 255 }
    return "$red,$green,$blue,$alpha"
}

function Get-Config([string]$Path) {
    if (-not (Test-Path $Path)) { throw "Missing iCal config file: $Path" }
    $config = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
    if ($null -eq $config) { throw "iCal config file is empty: $Path" }
    $calendars = @()
    if ($config.PSObject.Properties['calendars']) { $calendars = @($config.calendars) }
    # Accept the prior single-calendar form too, so existing local setups keep working.
    if ($calendars.Count -eq 0 -and $config.PSObject.Properties['icalUrl']) {
        $calendars = @([pscustomobject]@{ name = $config.calendarLabel; icalUrl = $config.icalUrl; color = '' })
    }
    $normalizedCalendars = New-Object System.Collections.Generic.List[object]
    foreach ($calendar in $calendars) {
        $url = [string]$calendar.icalUrl
        if ([string]::IsNullOrWhiteSpace($url) -or $url -match 'PASTE_YOUR') { throw 'Add every Google Calendar Secret address in iCal format to tools\\IcalCalendar.config.json, then refresh the skin.' }
        $name = [string]$calendar.name; if ([string]::IsNullOrWhiteSpace($name)) { $name = 'Google Calendar' }
        $color = Convert-HexColor ([string]$calendar.color) $name
        $normalizedCalendars.Add([ordered]@{ name = $name.Trim(); icalUrl = $url.Trim(); color = $color })
    }
    if ($normalizedCalendars.Count -eq 0) { throw 'Add at least one calendar to the calendars list in tools\\IcalCalendar.config.json.' }
    return [ordered]@{
        calendars = $normalizedCalendars.ToArray()
        use12HourTime = [bool]$config.use12HourTime; lookAheadDays = if ($config.lookAheadDays) { [int]$config.lookAheadDays } else { 14 }
        maxResults = if ($config.maxResults) { [int]$config.maxResults } else { 100 }
    }
}

function Unescape-IcalText([string]$Value) {
    if ($null -eq $Value) { return '' }
    return $Value.Replace('\\n', ' ').Replace('\\N', ' ').Replace('\\,', ',').Replace('\\;', ';').Replace('\\\\', '\\').Trim()
}

function Get-IcalDate([string]$Value, [string]$Parameters) {
    $allDay = $Value -match '^\d{8}$'
    if ($allDay) { return [ordered]@{ value = [datetime]::ParseExact($Value, 'yyyyMMdd', [Globalization.CultureInfo]::InvariantCulture); allDay = $true } }
    $format = if ($Value -match '^\d{8}T\d{6}Z$') { "yyyyMMdd'T'HHmmss'Z'" } elseif ($Value -match '^\d{8}T\d{4}$') { "yyyyMMdd'T'HHmm" } else { "yyyyMMdd'T'HHmmss" }
    if ($Value.EndsWith('Z')) {
        $utc = [datetime]::ParseExact($Value, $format, [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::AssumeUniversal)
        return [ordered]@{ value = $utc.ToLocalTime(); allDay = $false }
    }
    return [ordered]@{ value = [datetime]::ParseExact($Value, $format, [Globalization.CultureInfo]::InvariantCulture); allDay = $false }
}

function Get-Property([hashtable]$Event, [string]$Name) {
    if ($Event.ContainsKey($Name)) { return $Event[$Name] }
    return $null
}

function Convert-IcalEvents([string]$Content, [System.Collections.IDictionary]$Config, [System.Collections.IDictionary]$Calendar) {
    $lines = ([regex]::Replace($Content, "\r?\n[ `t]", '')) -split "\r?\n"
    $rawEvents = New-Object System.Collections.Generic.List[hashtable]; $current = $null
    foreach ($line in $lines) {
        if ($line -eq 'BEGIN:VEVENT') { $current = @{}; continue }
        if ($line -eq 'END:VEVENT') { if ($null -ne $current) { $rawEvents.Add($current) }; $current = $null; continue }
        if ($null -eq $current) { continue }
        if ($line -match '^([^:;]+)((?:;[^:]*)?):(.*)$') {
            $name = $matches[1].ToUpperInvariant()
            $property = [pscustomobject]@{ parameters = $matches[2]; value = $matches[3] }
            if ($name -eq 'EXDATE') {
                if (-not $current.ContainsKey($name)) { $current[$name] = New-Object System.Collections.Generic.List[object] }
                $current[$name].Add($property)
            } elseif (-not $current.ContainsKey($name)) { $current[$name] = $property }
        }
    }
    $now = Get-Date; $windowStart = $now.Date.AddDays(-1); $windowEnd = $now.Date.AddDays($Config.lookAheadDays + 1)
    $events = New-Object System.Collections.Generic.List[object]; $seen = @{}; $recurrenceOverrides = @{}
    # A VEVENT with RECURRENCE-ID replaces (or cancels) one occurrence of its parent series.
    foreach ($raw in $rawEvents) {
        $uidProperty = Get-Property $raw 'UID'; $recurrenceId = Get-Property $raw 'RECURRENCE-ID'
        if ($uidProperty -and $recurrenceId) {
            try { $recurrenceOverrides["$($uidProperty.value)|$((Get-IcalDate $recurrenceId.value $recurrenceId.parameters).value.Ticks)"] = $true } catch {}
        }
    }
    foreach ($raw in $rawEvents) {
        $status = Get-Property $raw 'STATUS'; if ($status -and $status.value -eq 'CANCELLED') { continue }
        $startProperty = Get-Property $raw 'DTSTART'; if (-not $startProperty) { continue }
        try { $startInfo = Get-IcalDate $startProperty.value $startProperty.parameters } catch { continue }
        $endProperty = Get-Property $raw 'DTEND'; $end = $null
        if ($endProperty) { try { $end = (Get-IcalDate $endProperty.value $endProperty.parameters).value } catch {} }
        if ($null -eq $end) { $end = $startInfo.value.AddHours(1) }
        $occurrences = @($startInfo.value)
        # Google iCal feeds encode recurring events as RRULE; expand common daily/weekly rules into the displayed window.
        $rrule = Get-Property $raw 'RRULE'
        if ($rrule) {
            $rules = @{}; foreach ($part in $rrule.value -split ';') { $pair = $part -split '=', 2; if ($pair.Count -eq 2) { $rules[$pair[0].ToUpperInvariant()] = $pair[1].ToUpperInvariant() } }
            $frequency = $rules['FREQ']; $interval = if ($rules['INTERVAL']) { [int]$rules['INTERVAL'] } else { 1 }; $count = if ($rules['COUNT']) { [int]$rules['COUNT'] } else { 0 }
            $until = $null; if ($rules['UNTIL']) { try { $until = (Get-IcalDate $rules['UNTIL'] '').value } catch {} }
            $occurrences = New-Object System.Collections.Generic.List[datetime]; $candidate = $startInfo.value; $iterations = 0
            # A common Google rule is FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR.  Moving
            # forward one whole week from DTSTART loses every listed weekday
            # except DTSTART's own day, so expand each BYDAY occurrence within
            # every recurrence week instead.
            if ($frequency -eq 'WEEKLY' -and $rules['BYDAY']) {
                $dayNumbers = @{ 'SU' = 0; 'MO' = 1; 'TU' = 2; 'WE' = 3; 'TH' = 4; 'FR' = 5; 'SA' = 6 }
                $weekDays = @($rules['BYDAY'] -split ',' | ForEach-Object {
                    $token = $_.Trim().ToUpperInvariant()
                    # Ignore an optional ordinal (for example 1MO); weekly
                    # rules only need the weekday portion.
                    $token = $token -replace '^[+-]?\d+', ''
                    if ($dayNumbers.ContainsKey($token)) { [int]$dayNumbers[$token] }
                } | Sort-Object -Unique)
                $weekStart = $startInfo.value.Date.AddDays(-[int]$startInfo.value.DayOfWeek)
                $occurrenceCount = 0; $stop = $false
                while ($weekStart -lt $windowEnd -and $iterations -lt 1000 -and -not $stop) {
                    foreach ($dayNumber in $weekDays) {
                        $candidate = $weekStart.AddDays($dayNumber).Add($startInfo.value.TimeOfDay)
                        if ($candidate -lt $startInfo.value) { continue }
                        if ($null -ne $until -and $candidate -gt $until) { $stop = $true; break }
                        if ($count -gt 0 -and $occurrenceCount -ge $count) { $stop = $true; break }
                        $occurrenceCount++
                        if ($candidate -ge $windowStart -and $candidate -lt $windowEnd) { $occurrences.Add($candidate) }
                    }
                    $weekStart = $weekStart.AddDays(7 * $interval)
                    $iterations++
                }
            } else {
                while ($candidate -lt $windowEnd -and $iterations -lt 1000 -and ($count -eq 0 -or $iterations -lt $count) -and ($null -eq $until -or $candidate -le $until)) {
                    if ($candidate -ge $windowStart) { $occurrences.Add($candidate) }
                    if ($frequency -eq 'DAILY') { $candidate = $candidate.AddDays($interval) }
                    elseif ($frequency -eq 'WEEKLY') { $candidate = $candidate.AddDays(7 * $interval) }
                    elseif ($frequency -eq 'MONTHLY') { $candidate = $candidate.AddMonths($interval) }
                    elseif ($frequency -eq 'YEARLY') { $candidate = $candidate.AddYears($interval) }
                    else { break }
                    $iterations++
                }
            }
        }
        foreach ($start in $occurrences) {
            if ($start -lt $windowStart -or $start -ge $windowEnd) { continue }
            $uidProperty = Get-Property $raw 'UID'; $uid = if ($uidProperty) { $uidProperty.value } else { $startInfo.value.ToString('o') }
            if (-not (Get-Property $raw 'RECURRENCE-ID') -and $recurrenceOverrides.ContainsKey("$uid|$($start.Ticks)")) { continue }
            $isExcluded = $false
            $exdateProperties = Get-Property $raw 'EXDATE'
            if ($exdateProperties) {
                foreach ($exdateProperty in $exdateProperties) {
                    foreach ($exdateValue in $exdateProperty.value -split ',') {
                        try {
                            $exdateInfo = Get-IcalDate $exdateValue $exdateProperty.parameters
                            if (($exdateInfo.allDay -and $start.Date -eq $exdateInfo.value.Date) -or (-not $exdateInfo.allDay -and $start.Ticks -eq $exdateInfo.value.Ticks)) { $isExcluded = $true; break }
                        } catch {}
                    }
                    if ($isExcluded) { break }
                }
            }
            if ($isExcluded) { continue }
            $key = "$($start.ToString('o'))|$uid"; if ($seen.ContainsKey($key)) { continue }; $seen[$key] = $true
            $eventEnd = $end.AddTicks(($start - $startInfo.value).Ticks); $allDay = [bool]$startInfo.allDay
            $summaryProperty = Get-Property $raw 'SUMMARY'; $summary = Unescape-IcalText $(if ($summaryProperty) { $summaryProperty.value } else { '' }); if ([string]::IsNullOrWhiteSpace($summary)) { $summary = '(Untitled event)' }
            $locationProperty = Get-Property $raw 'LOCATION'; $location = Unescape-IcalText $(if ($locationProperty) { $locationProperty.value } else { '' })
            $descriptionProperty = Get-Property $raw 'DESCRIPTION'; $details = Unescape-IcalText $(if ($descriptionProperty) { $descriptionProperty.value } else { '' })
            $clock = if ($Config.use12HourTime) { $start.ToString('h:mm') } else { $start.ToString('HH:mm') }
            $duration = if ($allDay) { 'ALL DAY' } elseif ($Config.use12HourTime) { '{0} - {1}' -f $start.ToString('h:mm'), $eventEnd.ToString('h:mm') } else { '{0} - {1}' -f $start.ToString('HH:mm'), $eventEnd.ToString('HH:mm') }
            $meta = @($Calendar.name); if ($location) { $meta += $location }; $meta += $duration
            $events.Add([pscustomobject][ordered]@{ year=$start.Year; month=$start.Month; day=$start.Day; sortTime=if ($allDay) {'00:00'} else {$start.ToString('HH:mm')}; timeLabel=if ($allDay) { "$($start.ToString('ddd').ToUpperInvariant()) ALL DAY" } else { "$($start.ToString('ddd').ToUpperInvariant()) $clock" }; title=$summary; durationLabel=$duration; meta=($meta -join ' - '); details=$details; color=$Calendar.color })
        }
    }
    return @($events | Sort-Object year, month, day, sortTime, title | Select-Object -First $Config.maxResults)
}

function Lua([object]$Value) { if ($null -eq $Value) { return '""' }; return '"' + ([string]$Value).Replace('\\','\\\\').Replace('"','\\"').Replace("`r",' ').Replace("`n",' ') + '"' }
function Write-Cache([object[]]$Events, [string]$Path) {
    $rows = @('return {', '  source = "google-ical",', ('  generatedAt = ' + (Lua (Get-Date -Format 'yyyy-MM-dd HH:mm')) + ','), '  events = {')
    foreach ($event in $Events) { $rows += '    {'; foreach ($key in @('year','month','day','sortTime','timeLabel','title','durationLabel','meta','details','color')) { $value = $event.$key; $rows += "      $key = " + $(if ($key -in @('year','month','day')) {$value} else {Lua $value}) + ',' }; $rows += '    },' }
    $rows += '  }'; $rows += '}'; [IO.Directory]::CreateDirectory((Split-Path -Parent $Path)) | Out-Null; [IO.File]::WriteAllText($Path, ($rows -join [Environment]::NewLine), (New-Object Text.UTF8Encoding($false)))
}

function Write-TimelineInclude([int]$SlotCount, [string]$Path) {
    $SlotCount = [Math]::Max(20, $SlotCount)
    $variableRows = @('; Generated by Sync-IcalCalendar.ps1. Do not edit manually.', "TimelineSlotCount=$SlotCount")
    for ($slot = 21; $slot -le $SlotCount; $slot++) {
        $variableRows += @("DayEvent${slot}X=70", "DayEvent${slot}Y=210", "DayEvent${slot}TextY=214", "DayEvent${slot}W=1", "DayEvent${slot}H=1", "DayEvent${slot}Color=#RowColor#", "DayEvent${slot}Title=", "DayEvent${slot}Time=")
    }
    $rows = @('; Generated by Sync-IcalCalendar.ps1. Do not edit manually.')
    for ($slot = 21; $slot -le $SlotCount; $slot++) {
        $rows += @(
            '', "[MeterDayEvent$slot]", 'Meter=Shape', 'Group=Flyout', "Shape=Rectangle (#PanelX#+#DayEvent${slot}X#),(#PanelY#+#DayEvent${slot}Y#),#DayEvent${slot}W#,#DayEvent${slot}H#,3 | Fill Color #DayEvent${slot}Color# | StrokeWidth 1 | Stroke Color #IconHighlightColor#", 'Hidden=1', 'DynamicVariables=1',
            '', "[MeterDayEventTitle$slot]", 'Meter=String', 'Group=Flyout', 'MeterStyle=StyleRowTitle', "X=(#PanelX#+#DayEvent${slot}X#+6)", "Y=(#PanelY#+#DayEvent${slot}TextY#)", "W=(#DayEvent${slot}W#-10)", "Text=#DayEvent${slot}Title#", 'Hidden=1', 'DynamicVariables=1',
            '', "[MeterDayEventTime$slot]", 'Meter=String', 'Group=Flyout', 'MeterStyle=StyleRowMeta', "X=(#PanelX#+#DayEvent${slot}X#+6)", "Y=(#PanelY#+#DayEvent${slot}Y#+24)", "W=(#DayEvent${slot}W#-10)", "Text=#DayEvent${slot}Time#", 'Hidden=1', 'DynamicVariables=1'
        )
    }
    $variablesPath = Join-Path (Split-Path -Parent $Path) 'DayTimeline.generated.variables.inc'
    [IO.File]::WriteAllText($variablesPath, ($variableRows -join [Environment]::NewLine), (New-Object Text.UTF8Encoding($false)))
    [IO.File]::WriteAllText($Path, ($rows -join [Environment]::NewLine), (New-Object Text.UTF8Encoding($false)))
}

$output = Resolve-ProjectPath $OutputPath; $config = Get-Config (Resolve-ProjectPath $ConfigPath); $events = New-Object System.Collections.Generic.List[object]
foreach ($calendar in $config.calendars) {
    $response = Invoke-WebRequest -UseBasicParsing -Uri $calendar.icalUrl -Headers @{ 'User-Agent' = 'Rainmeter Google iCal Sync' }
    if ([string]::IsNullOrWhiteSpace($response.Content) -or $response.Content -notmatch 'BEGIN:VCALENDAR') { throw "The '$($calendar.name)' URL did not return an iCalendar (.ics) feed." }
    foreach ($event in (Convert-IcalEvents $response.Content $config $calendar)) { $events.Add($event) }
}
$events = @($events | Sort-Object year, month, day, sortTime, title | Select-Object -First $config.maxResults); Write-Cache $events $output
$busiestDayCount = @($events | Group-Object { '{0:D4}-{1:D2}-{2:D2}' -f $_.year, $_.month, $_.day } | Measure-Object -Property Count -Maximum).Maximum
Write-TimelineInclude -SlotCount ([int]$busiestDayCount) -Path (Join-Path (Split-Path -Parent $output) 'DayTimeline.generated.inc')
Write-Host ("Wrote iCal cache to {0} at {1} with {2} events" -f $output, (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $events.Count)
