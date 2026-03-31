local state = {
  expanded = true,
  view = "day",
  settingsOpen = false,
  selectedOffset = 0,
  scrollOffset = 0,
  visibleRows = 4,
  lastManualInteractionAt = 0,
  lastAutoJumpMinuteKey = "",
  dayIndex = {},
  events = {}
}

local months = { "JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC" }
local weekdays = { "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday" }
local cacheFilePath = nil
local configFilePath = nil
local rootSkinPath = nil
local flyoutMarkerPath = nil
local update_settings_visibility
local manualInteractionCooldownSeconds = 60

local function set_var(name, value)
  SKIN:Bang("!SetVariable", name, tostring(value))
end

local function read_text_file(path)
  local file = io.open(path, "r")
  if not file then
    return nil
  end

  local contents = file:read("*a")
  file:close()
  return contents
end

local function write_text_file(path, contents)
  local file = io.open(path, "w")
  if not file then
    return false
  end

  file:write(contents)
  file:close()
  return true
end

local function delete_file(path)
  if not path or path == "" then
    return
  end

  os.remove(path)
end

local function update_time_format_label()
  if not configFilePath or configFilePath == "" then
    set_var("TimeFormatLabel", "[ ] 12-HOUR")
    return
  end

  local contents = read_text_file(configFilePath)
  if not contents then
    set_var("TimeFormatLabel", "[ ] 12-HOUR")
    return
  end

  if contents and contents:match('"use12HourTime"%s*:%s*true') then
    set_var("TimeFormatLabel", "[x] 12-HOUR")
  else
    set_var("TimeFormatLabel", "[ ] 12-HOUR")
  end
end

local function mark_manual_interaction()
  state.lastManualInteractionAt = os.time()
end

local function current_minute_key()
  return os.date("%Y-%m-%d %H:%M")
end

local function normalize_root_skin_path(path)
  path = tostring(path or "")
  path = path:gsub("[/\\]+$", "")
  path = path:gsub("[/\\]Flyout$", "")
  path = path:gsub("GoogleCalendarFlyout$", "GoogleCalendar")
  return path .. "\\"
end

local function use_12_hour_time_enabled()
  if not configFilePath or configFilePath == "" then
    return false
  end

  local contents = read_text_file(configFilePath)
  if not contents then
    return false
  end

  return contents and contents:match('"use12HourTime"%s*:%s*true') ~= nil
end

local function set_use_12_hour_time(enabled)
  if not configFilePath or configFilePath == "" then
    return false
  end

  local contents = read_text_file(configFilePath)
  if not contents then
    return false
  end

  local replacement = '"use12HourTime": ' .. tostring(enabled)
  local updated, count = contents:gsub('"use12HourTime"%s*:%s*%a+', replacement, 1)

  if count == 0 then
    updated, count = contents:gsub('%s*}$', ',\n  "use12HourTime": ' .. tostring(enabled) .. '\n}', 1)
    if count == 0 then
      return false
    end
  end

  return write_text_file(configFilePath, updated)
end

local function event_key(event)
  return string.format("%04d-%02d-%02d", event.year, event.month, event.day)
end

local function event_minutes(event)
  local hour, minute = tostring(event.sortTime or "00:00"):match("^(%d%d):(%d%d)$")
  if not hour then
    return 0
  end

  return (tonumber(hour) * 60) + tonumber(minute)
end

local function event_timestamp(event)
  return os.time({
    year = event.year,
    month = event.month,
    day = event.day,
    hour = math.floor(event_minutes(event) / 60),
    min = event_minutes(event) % 60,
    sec = 0
  })
end

local function selected_date_table()
  local now = os.time()
  return os.date("*t", now + (state.selectedOffset * 86400))
end

local function date_label(date_tbl)
  return string.format("%s, %s %02d", weekdays[date_tbl.wday], months[date_tbl.month], date_tbl.day)
end

local function normalize_event(raw)
  if type(raw) ~= "table" then
    return nil
  end

  if not raw.year or not raw.month or not raw.day or not raw.title then
    return nil
  end

  return {
    year = tonumber(raw.year),
    month = tonumber(raw.month),
    day = tonumber(raw.day),
    sortTime = tostring(raw.sortTime or "99:99"),
    timeLabel = tostring(raw.timeLabel or "--"),
    title = tostring(raw.title),
    durationLabel = tostring(raw.durationLabel or ""),
    meta = tostring(raw.meta or "")
  }
end

local function ascii_only(text)
  if not text then
    return ""
  end

  text = tostring(text)
  local out = {}

  for i = 1, #text do
    local b = text:byte(i)
    if b and b < 128 then
      out[#out + 1] = string.char(b)
    else
      out[#out + 1] = " "
    end
  end

  text = table.concat(out)
  text = text:gsub("%s%s+", " ")
  text = text:gsub("^%s+", "")
  text = text:gsub("%s+$", "")
  return text
end

local function sort_events()
  table.sort(state.events, function(a, b)
    if a.year ~= b.year then
      return a.year < b.year
    end
    if a.month ~= b.month then
      return a.month < b.month
    end
    if a.day ~= b.day then
      return a.day < b.day
    end
    return a.sortTime < b.sortTime
  end)
end

local function rebuild_day_index()
  state.dayIndex = {}
  for _, event in ipairs(state.events) do
    local key = event_key(event)
    if not state.dayIndex[key] then
      state.dayIndex[key] = {}
    end
    table.insert(state.dayIndex[key], event)
  end
end

local function reset_row(index)
  set_var("Row" .. index .. "Bg", SKIN:GetVariable("EmptyRowColor"))
  set_var("Row" .. index .. "Time", "--")
  set_var("Row" .. index .. "Title", "")
  set_var("Row" .. index .. "Meta", "")
end

local function duration_minutes_from_meta(meta)
  meta = tostring(meta or "")

  if meta:find("All%-day", 1, false) then
    return 1440
  end

  local hours = meta:match("(%d+)%s*hr")
  local minutes = meta:match("(%d+)%s*min")
  local total = 0

  if hours then
    total = total + (tonumber(hours) * 60)
  end

  if minutes then
    total = total + tonumber(minutes)
  end

  if total == 0 then
    return nil
  end

  return total
end

local function event_duration_label(event)
  local durationLabel = tostring(event.durationLabel or "")
  if durationLabel ~= "" then
    return durationLabel:upper()
  end

  if event.sortTime == "00:00" and tostring(event.timeLabel or ""):find("ALL DAY", 1, true) then
    return "ALL DAY"
  end

  local duration = duration_minutes_from_meta(event.meta)
  if duration == 1440 then
    return "ALL DAY"
  end
  if duration and duration > 0 then
    local hours = math.floor(duration / 60)
    local minutes = duration % 60
    if hours > 0 and minutes > 0 then
      return string.format("%d HR %d MIN", hours, minutes)
    end
    if hours > 0 then
      return string.format("%d HR", hours)
    end
    return string.format("%d MIN", minutes)
  end

  return tostring(event.timeLabel or "--")
end

local function event_day_duration_label(event)
  return string.format("%s %02d\n%s", months[event.month], event.day, event_duration_label(event))
end

local function fill_row(index, event)
  set_var("Row" .. index .. "Bg", SKIN:GetVariable("RowColor"))
  set_var("Row" .. index .. "Time", event_day_duration_label(event))
  set_var("Row" .. index .. "Title", ascii_only(event.title))
  set_var("Row" .. index .. "Meta", ascii_only(event.meta))
end

local function update_panel_visibility()
  if state.expanded then
    set_var("PanelX", SKIN:GetVariable("ExpandedPanelX"))
    set_var("PanelHidden", 0)
    SKIN:Bang("!ShowMeterGroup", "Flyout")
  else
    set_var("PanelX", SKIN:GetVariable("CollapsedPanelX"))
    set_var("PanelHidden", 1)
    SKIN:Bang("!HideMeterGroup", "Flyout")
  end

  update_settings_visibility()
end

update_settings_visibility = function()
  if state.settingsOpen then
    SKIN:Bang("!ShowMeter", "MeterSettingsOverlay")
    SKIN:Bang("!ShowMeter", "MeterSettingsTitle")
    SKIN:Bang("!ShowMeter", "MeterSettingsCopy")
    SKIN:Bang("!ShowMeter", "MeterSettingsTimeFormat")
    SKIN:Bang("!ShowMeter", "MeterSettingsSetup")
    SKIN:Bang("!ShowMeter", "MeterSettingsBack")
  else
    SKIN:Bang("!HideMeter", "MeterSettingsOverlay")
    SKIN:Bang("!HideMeter", "MeterSettingsTitle")
    SKIN:Bang("!HideMeter", "MeterSettingsCopy")
    SKIN:Bang("!HideMeter", "MeterSettingsTimeFormat")
    SKIN:Bang("!HideMeter", "MeterSettingsSetup")
    SKIN:Bang("!HideMeter", "MeterSettingsBack")
  end
end

local function update_tab_colors()
  local selectedTabText = SKIN:GetVariable("SelectedTabText")
  local selectedTabBg = SKIN:GetVariable("SelectedTabBg")
  local idleTabText = SKIN:GetVariable("IdleTabText")
  local idleTabBg = SKIN:GetVariable("IdleTabBg")

  if state.view == "day" then
    set_var("DayTabColor", selectedTabText)
    set_var("DayTabBg", selectedTabBg)
    set_var("ScheduleTabColor", idleTabText)
    set_var("ScheduleTabBg", idleTabBg)
    set_var("ViewLabel", "Selected Day")
  else
    set_var("DayTabColor", idleTabText)
    set_var("DayTabBg", idleTabBg)
    set_var("ScheduleTabColor", selectedTabText)
    set_var("ScheduleTabBg", selectedTabBg)
    set_var("ViewLabel", "Upcoming Schedule")
  end
end

local function update_status(source, generatedAt)
  local status = "Cache loaded"
  if source == "google-calendar" then
    status = "Google Calendar"
  elseif source == "mock-sync" then
    status = "Mock sync cache"
  end

  if generatedAt and generatedAt ~= "" then
    status = status .. "  |  " .. generatedAt
  end

  set_var("SyncStatus", status)
end

local function update_date_text()
  local date_tbl = selected_date_table()
  set_var("DisplayDate", date_label(date_tbl))
  SKIN:Bang("!SetOption", "MeterIconMonth", "Text", months[date_tbl.month])
  SKIN:Bang("!SetOption", "MeterIconDay", "Text", tostring(date_tbl.day))
end

local function visible_events()
  if state.view == "schedule" then
    return state.events
  end

  local date_tbl = selected_date_table()
  local key = string.format("%04d-%02d-%02d", date_tbl.year, date_tbl.month, date_tbl.day)
  return state.dayIndex[key] or {}
end

local function jump_to_now()
  local events = visible_events()
  if #events == 0 then
    return
  end

  local now = os.date("*t")
  if state.view == "day" then
    if state.selectedOffset ~= 0 then
      return
    end

    local now_minutes = (now.hour * 60) + now.min
    local insertion_index = #events + 1
    for i, event in ipairs(events) do
      if event_minutes(event) >= now_minutes then
        insertion_index = i
        break
      end
    end

    state.scrollOffset = math.max(0, insertion_index - 2)
    return
  end

  local now_ts = os.time()
  local insertion_index = #events + 1
  for i, event in ipairs(events) do
    if event_timestamp(event) >= now_ts then
      insertion_index = i
      break
    end
  end

  state.scrollOffset = math.max(0, insertion_index - 2)
end

local function maybe_auto_jump_to_now()
  if state.settingsOpen then
    return
  end

  local minuteKey = current_minute_key()
  if state.lastAutoJumpMinuteKey == minuteKey then
    return
  end

  local now = os.time()
  if state.lastManualInteractionAt > 0 and (now - state.lastManualInteractionAt) < manualInteractionCooldownSeconds then
    return
  end

  local previousOffset = state.scrollOffset
  jump_to_now()
  state.lastAutoJumpMinuteKey = minuteKey

  if state.scrollOffset ~= previousOffset and state.expanded then
    update_rows()
    redraw()
  end
end

local function update_rows()
  local events = visible_events()
  local count = #events
  local maxOffset = math.max(0, count - state.visibleRows)

  if state.scrollOffset > maxOffset then
    state.scrollOffset = maxOffset
  end

  if count == 0 then
    set_var("Row1Bg", SKIN:GetVariable("EmptyRowColor"))
    set_var("Row1Time", "--")
    set_var("Row1Title", "No events in this view")
    set_var("Row1Meta", "Use Schedule view or refresh again")
    for row = 2, state.visibleRows do
      reset_row(row)
    end
    return
  end

  for row = 1, state.visibleRows do
    local event = events[state.scrollOffset + row]
    if event then
      fill_row(row, event)
    else
      reset_row(row)
    end
  end
end

local function redraw()
  SKIN:Bang("!UpdateMeter", "*")
  SKIN:Bang("!Redraw")
end

local function load_cache_file()
  if not cacheFilePath or cacheFilePath == "" then
    return nil, "Cache file path is not initialized"
  end

  local chunk, err = loadfile(cacheFilePath)
  if not chunk then
    return nil, err
  end

  local ok, payload = pcall(chunk)
  if not ok then
    return nil, payload
  end

  if type(payload) ~= "table" or type(payload.events) ~= "table" then
    return nil, "Cache file returned invalid payload"
  end

  local events = {}
  for _, raw in ipairs(payload.events) do
    local event = normalize_event(raw)
    if event then
      table.insert(events, event)
    end
  end

  return {
    events = events,
    source = tostring(payload.source or "cache"),
    generatedAt = tostring(payload.generatedAt or "")
  }, nil
end

local function show_error(message)
  set_var("SyncStatus", "Lua/cache error")
  set_var("Row1Bg", SKIN:GetVariable("EmptyRowColor"))
  set_var("Row1Time", "ERR")
  set_var("Row1Title", "Calendar load failed")
  set_var("Row1Meta", tostring(message):sub(1, 160))
  for row = 2, state.visibleRows do
    reset_row(row)
  end
  redraw()
end

local function load_events()
  local payload, err = load_cache_file()
  if not payload then
    return false, err
  end

  state.events = payload.events
  sort_events()
  rebuild_day_index()
  update_status(payload.source, payload.generatedAt)
  return true
end

function Initialize()
  rootSkinPath = normalize_root_skin_path(SKIN:GetVariable("CURRENTPATH"))
  cacheFilePath = rootSkinPath .. "@Resources\\Data\\CalendarCache.lua"
  configFilePath = rootSkinPath .. "tools\\GoogleCalendar.config.json"
  flyoutMarkerPath = rootSkinPath .. "tools\\FlyoutOpen.marker"
  state.visibleRows = tonumber(SKIN:GetVariable("VisibleRows")) or 5
  write_text_file(flyoutMarkerPath, "open")
  if state.expanded then
    set_var("PanelX", SKIN:GetVariable("ExpandedPanelX"))
  else
    set_var("PanelX", SKIN:GetVariable("CollapsedPanelX"))
  end
  if not load_events() then
    show_error("Could not load " .. cacheFilePath)
    return
  end

  update_time_format_label()
  update_panel_visibility()
  update_settings_visibility()
  update_tab_colors()
  update_date_text()
  jump_to_now()
  state.lastAutoJumpMinuteKey = current_minute_key()
  update_rows()
  redraw()
end

function ToggleExpanded()
  mark_manual_interaction()
  state.settingsOpen = false
  update_settings_visibility()
  state.expanded = not state.expanded
  update_panel_visibility()
  redraw()
end

function ShowSettings()
  mark_manual_interaction()
  state.settingsOpen = true
  update_settings_visibility()
  redraw()
end

function HideSettings()
  mark_manual_interaction()
  state.settingsOpen = false
  update_settings_visibility()
  redraw()
end

function ToggleTimeFormat()
  mark_manual_interaction()
  local nextValue = not use_12_hour_time_enabled()
  if not set_use_12_hour_time(nextValue) then
    show_error("Could not update " .. tostring(configFilePath))
    return
  end

  update_time_format_label()
  set_var("SyncStatus", "Syncing...")
  redraw()
  SKIN:Bang("!CommandMeasure", "MeasureRunSync", "Run")
end

function SetView(view)
  if view ~= "day" and view ~= "schedule" then
    return
  end
  mark_manual_interaction()
  state.view = view
  state.scrollOffset = 0
  update_tab_colors()
  update_rows()
  redraw()
end

function ShowDayView()
  if state.view == "day" then
    jump_to_now()
    update_rows()
    redraw()
    return
  end

  SetView("day")
end

function ShowScheduleView()
  if state.view == "schedule" then
    jump_to_now()
    update_rows()
    redraw()
    return
  end

  SetView("schedule")
end

function ShiftDate(delta)
  mark_manual_interaction()
  state.selectedOffset = state.selectedOffset + tonumber(delta)
  state.scrollOffset = 0
  update_date_text()
  update_rows()
  redraw()
end

function PrevDay()
  ShiftDate(-1)
end

function NextDay()
  ShiftDate(1)
end

function Scroll(delta)
  mark_manual_interaction()
  local events = visible_events()
  local maxOffset = math.max(0, #events - state.visibleRows)
  local nextOffset = state.scrollOffset + tonumber(delta)

  if nextOffset < 0 then
    nextOffset = 0
  end
  if nextOffset > maxOffset then
    nextOffset = maxOffset
  end

  if nextOffset ~= state.scrollOffset then
    state.scrollOffset = nextOffset
    update_rows()
    redraw()
  end
end

function RefreshData()
  local ok, err = load_events()
  if not ok then
    show_error(err or "Unknown cache load failure")
    return
  end

  update_time_format_label()
  jump_to_now()
  state.lastAutoJumpMinuteKey = current_minute_key()
  update_tab_colors()
  update_date_text()
  update_rows()
  redraw()
end

function CloseFlyout()
  delete_file(flyoutMarkerPath)
  SKIN:Bang("!DeactivateConfig", "GoogleCalendarFlyout")
end

function Update()
  maybe_auto_jump_to_now()
  return ""
end
