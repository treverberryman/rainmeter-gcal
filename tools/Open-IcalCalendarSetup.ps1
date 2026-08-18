param(
    [Parameter(Mandatory = $true)]
    [string]$ConfigPath,
    [Parameter(Mandatory = $true)]
    [string]$ExamplePath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

function Read-Config([string]$Path) {
    if (Test-Path -LiteralPath $Path) {
        try { return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json } catch { throw "Could not read the existing configuration: $($_.Exception.Message)" }
    }
    if (-not (Test-Path -LiteralPath $ExamplePath)) { throw "Missing iCal configuration template: $ExamplePath" }
    return Get-Content -LiteralPath $ExamplePath -Raw | ConvertFrom-Json
}

function Write-Config([object]$Value, [string]$Path) {
    $directory = Split-Path -Parent $Path
    [IO.Directory]::CreateDirectory($directory) | Out-Null
    $json = $Value | ConvertTo-Json -Depth 5
    [IO.File]::WriteAllText($Path, $json, (New-Object Text.UTF8Encoding($false)))
}

$existing = Read-Config $ConfigPath
$form = New-Object System.Windows.Forms.Form
$form.Text = 'rainmeter-gcal setup'
$form.StartPosition = 'CenterScreen'
$form.ClientSize = New-Object System.Drawing.Size(760, 510)
$form.MinimumSize = New-Object System.Drawing.Size(760, 510)
$form.Font = New-Object System.Drawing.Font('Segoe UI', 9)

$title = New-Object System.Windows.Forms.Label
$title.Text = 'Connect your Google Calendars'
$title.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 15)
$title.AutoSize = $true
$title.Location = New-Object System.Drawing.Point(20, 18)
$form.Controls.Add($title)

$instructions = New-Object System.Windows.Forms.Label
$instructions.Text = "For each calendar: Google Calendar > Settings and sharing > Integrate calendar > Secret address in iCal format. Paste that private link below."
$instructions.Location = New-Object System.Drawing.Point(22, 55)
$instructions.Size = New-Object System.Drawing.Size(716, 40)
$form.Controls.Add($instructions)

$link = New-Object System.Windows.Forms.LinkLabel
$link.Text = 'Open Google Calendar'
$link.AutoSize = $true
$link.Location = New-Object System.Drawing.Point(22, 96)
$link.add_LinkClicked({ Start-Process 'https://calendar.google.com/' })
$form.Controls.Add($link)

$grid = New-Object System.Windows.Forms.DataGridView
$grid.Location = New-Object System.Drawing.Point(20, 125)
$grid.Size = New-Object System.Drawing.Size(720, 260)
$grid.Anchor = 'Top,Left,Right'
$grid.AllowUserToAddRows = $false
$grid.AllowUserToResizeRows = $false
$grid.RowHeadersVisible = $false
$grid.SelectionMode = 'FullRowSelect'
$grid.AutoSizeRowsMode = 'AllCells'
$grid.Columns.Add('name', 'Calendar name') | Out-Null
$grid.Columns.Add('icalUrl', 'Secret iCal URL') | Out-Null
$grid.Columns.Add('color', 'Color') | Out-Null
$remove = New-Object System.Windows.Forms.DataGridViewButtonColumn
$remove.Name = 'remove'; $remove.HeaderText = ''; $remove.Text = 'Remove'; $remove.UseColumnTextForButtonValue = $true
$grid.Columns.Add($remove) | Out-Null
$grid.Columns['name'].Width = 145
$grid.Columns['icalUrl'].Width = 400
$grid.Columns['color'].Width = 75
$grid.Columns['remove'].Width = 75
$form.Controls.Add($grid)

$colors = @('#4285F4DC', '#34A853DC', '#FBBC04DC', '#EA4335DC', '#A142F4DC')
$calendarItems = @($existing.calendars)
foreach ($calendar in $calendarItems) {
    $grid.Rows.Add([string]$calendar.name, [string]$calendar.icalUrl, [string]$calendar.color) | Out-Null
}
if ($grid.Rows.Count -eq 0) { $grid.Rows.Add('Personal', '', $colors[0]) | Out-Null }

$add = New-Object System.Windows.Forms.Button
$add.Text = 'Add calendar'
$add.Location = New-Object System.Drawing.Point(20, 400)
$add.Size = New-Object System.Drawing.Size(110, 30)
$add.add_Click({
    $index = $grid.Rows.Count
    $grid.Rows.Add("Calendar $($index + 1)", '', $colors[$index % $colors.Count]) | Out-Null
})
$form.Controls.Add($add)

$syncNow = New-Object System.Windows.Forms.CheckBox
$syncNow.Text = 'Sync calendars after saving'
$syncNow.Checked = $true
$syncNow.AutoSize = $true
$syncNow.Location = New-Object System.Drawing.Point(20, 447)
$form.Controls.Add($syncNow)

$cancel = New-Object System.Windows.Forms.Button
$cancel.Text = 'Cancel'
$cancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
$cancel.Location = New-Object System.Drawing.Point(570, 445)
$cancel.Size = New-Object System.Drawing.Size(80, 32)
$form.Controls.Add($cancel)

$save = New-Object System.Windows.Forms.Button
$save.Text = 'Save'
$save.Location = New-Object System.Drawing.Point(660, 445)
$save.Size = New-Object System.Drawing.Size(80, 32)
$form.Controls.Add($save)
$form.AcceptButton = $save
$form.CancelButton = $cancel

$grid.add_CellContentClick({
    param($sender, $event)
    if ($event.RowIndex -ge 0 -and $grid.Columns[$event.ColumnIndex].Name -eq 'remove') { $grid.Rows.RemoveAt($event.RowIndex) }
})

$save.add_Click({
    $grid.EndEdit()
    $calendars = New-Object System.Collections.Generic.List[object]
    foreach ($row in $grid.Rows) {
        $name = ([string]$row.Cells['name'].Value).Trim()
        $url = ([string]$row.Cells['icalUrl'].Value).Trim()
        $color = ([string]$row.Cells['color'].Value).Trim()
        if ([string]::IsNullOrWhiteSpace($url)) { [Windows.Forms.MessageBox]::Show('Add a Secret iCal URL for every calendar, or remove the empty row.', 'Setup incomplete'); return }
        $uri = $null
        if (-not [Uri]::TryCreate($url, [UriKind]::Absolute, [ref]$uri) -or $uri.Scheme -ne 'https') { [Windows.Forms.MessageBox]::Show("'$name' needs a valid https Secret iCal URL.", 'Invalid URL'); return }
        if ([string]::IsNullOrWhiteSpace($name)) { $name = 'Google Calendar' }
        if ($color -notmatch '^#?[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$') { [Windows.Forms.MessageBox]::Show("'$name' needs a color such as #4285F4 or #4285F4DC.", 'Invalid color'); return }
        if ($color[0] -ne '#') { $color = "#$color" }
        $calendars.Add([ordered]@{ name = $name; icalUrl = $url; color = $color })
    }
    if ($calendars.Count -eq 0) { [Windows.Forms.MessageBox]::Show('Add at least one calendar.', 'Setup incomplete'); return }
    $config = [ordered]@{
        timeZone = if ($existing.timeZone) { [string]$existing.timeZone } else { [TimeZoneInfo]::Local.Id }
        use12HourTime = if ($null -ne $existing.use12HourTime) { [bool]$existing.use12HourTime } else { $true }
        lookAheadDays = if ($existing.lookAheadDays) { [int]$existing.lookAheadDays } else { 14 }
        maxResults = if ($existing.maxResults) { [int]$existing.maxResults } else { 100 }
        calendars = $calendars.ToArray()
    }
    try {
        Write-Config $config $ConfigPath
        if ($syncNow.Checked) {
            $projectRoot = Split-Path -Parent $PSScriptRoot
            & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'Sync-IcalCalendar.ps1') -OutputPath (Join-Path $projectRoot '@Resources\Data\CalendarCache.lua') -ConfigPath $ConfigPath
            if ($LASTEXITCODE -ne 0) { throw 'The configuration was saved, but syncing failed. Check the Secret iCal URLs and try Refresh from the skin.' }
        }
        [Windows.Forms.MessageBox]::Show('Calendar setup saved.' + $(if ($syncNow.Checked) { ' The event cache was refreshed.' } else { '' }), 'rainmeter-gcal setup')
        $form.DialogResult = [System.Windows.Forms.DialogResult]::OK
        $form.Close()
    } catch { [Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Setup error') }
})

[void]$form.ShowDialog()
