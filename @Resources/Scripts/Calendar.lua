local state = {
  expanded = true,
  view = "day",
  settingsOpen = false,
  detailsOpen = false,
  timelineSlotEvents = {},
  selectedOffset = 0,
  scrollOffset = 0,
  visibleRows = 4,
  timelineStartHour = 6,
  timelineHours = 7,
  timelinePixelsPerHour = 56,
  timelineTopY = 160,
  timelineSlots = 20,
  lastManualInteractionAt = 0,
  lastAutoJumpMinuteKey = "",
  lastNowIndicatorMinuteKey = "",
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
local update_details_visibility
local visible_events
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
  path = path:gsub("rainmeter%-gcal%-flyout$", "rainmeter-gcal")
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
    meta = tostring(raw.meta or ""),
    details = tostring(raw.details or ""),
    color = tostring(raw.color or "")
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

local function wrap_text(text, limit)
  local words, lines, line = {}, {}, ""
  for word in tostring(text or ""):gmatch("%S+") do table.insert(words, word) end
  for _, word in ipairs(words) do
    if #line > 0 and (#line + #word + 1) > limit then
      table.insert(lines, line)
      line = word
    else
      line = (#line > 0) and (line .. " " .. word) or word
    end
  end
  if #line > 0 then table.insert(lines, line) end
  return table.concat(lines, "\n")
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
  local color = tostring(event.color or "")
  if not color:match("^%d+,%d+,%d+,%d+$") then
    color = SKIN:GetVariable("RowColor")
  end
  set_var("Row" .. index .. "Bg", color)
  set_var("Row" .. index .. "Time", event_day_duration_label(event))
  set_var("Row" .. index .. "Title", ascii_only(event.title))
  set_var("Row" .. index .. "Meta", ascii_only(event.meta))
end

local function set_timeline_meter_visibility(index, visible)
  local action = visible and "!ShowMeter" or "!HideMeter"
  SKIN:Bang(action, "MeterDayEvent" .. index)
  SKIN:Bang(action, "MeterDayEventTitle" .. index)
  SKIN:Bang(action, "MeterDayEventTime" .. index)
end

local function set_day_view_visibility(visible)
  local action = visible and "!ShowMeter" or "!HideMeter"
  for index = 1, 8 do
    SKIN:Bang(action, "MeterTimelineLabel" .. index)
    SKIN:Bang(action, "MeterTimelineLine" .. index)
  end
  for index = 1, state.timelineSlots do
    set_timeline_meter_visibility(index, visible)
  end
  SKIN:Bang(action, "MeterAllDayBackground")
  SKIN:Bang(action, "MeterAllDayText")
  SKIN:Bang(visible and "!ShowMeter" or "!HideMeter", "MeterNowIndicator")
  SKIN:Bang(visible and "!ShowMeter" or "!HideMeter", "MeterNowIndicatorText")
  for index = 1, state.visibleRows do
    SKIN:Bang(visible and "!HideMeter" or "!ShowMeter", "MeterRowBackground" .. index)
    SKIN:Bang(visible and "!HideMeter" or "!ShowMeter", "MeterRowTime" .. index)
    SKIN:Bang(visible and "!HideMeter" or "!ShowMeter", "MeterRowTitle" .. index)
    SKIN:Bang(visible and "!HideMeter" or "!ShowMeter", "MeterRowMeta" .. index)
  end
end

local function update_timeline_now_indicator()
  if state.detailsOpen or state.settingsOpen or state.view ~= "day" or state.selectedOffset ~= 0 then
    SKIN:Bang("!HideMeter", "MeterNowIndicator")
    SKIN:Bang("!HideMeter", "MeterNowIndicatorText")
    return
  end

  local now = os.date("*t")
  local nowMinutes = (now.hour * 60) + now.min
  local startMinute = state.timelineStartHour * 60
  local endMinute = startMinute + (state.timelineHours * 60)
  if nowMinutes < startMinute or nowMinutes > endMinute then
    SKIN:Bang("!HideMeter", "MeterNowIndicator")
    SKIN:Bang("!HideMeter", "MeterNowIndicatorText")
    return
  end

  local y = math.floor(state.timelineTopY + (((nowMinutes - startMinute) / 60) * state.timelinePixelsPerHour))
  set_var("NowIndicatorY", y)
  local timeText
  if use_12_hour_time_enabled() then
    local hour = now.hour % 12
    if hour == 0 then hour = 12 end
    timeText = string.format("%d:%02d", hour, now.min)
  else
    timeText = string.format("%02d:%02d", now.hour, now.min)
  end
  local trackedCharacters = {}
  for index = 1, #timeText do
    trackedCharacters[#trackedCharacters + 1] = timeText:sub(index, index)
  end
  -- Rainmeter String meters have no character-spacing option. Use ordinary
  -- spaces here: special Unicode spaces are decoded inconsistently by its
  -- variable update path.
  set_var("NowIndicatorTime", table.concat(trackedCharacters, " "))
  SKIN:Bang("!ShowMeter", "MeterNowIndicator")
  SKIN:Bang("!ShowMeter", "MeterNowIndicatorText")
end

local function position_timeline_near_now()
  local now = os.date("*t")
  -- Leave about one hour above the current hour. This puts "now" near the
  -- upper third of the six-hour window while retaining useful context.
  state.timelineStartHour = math.max(0, math.min(24 - state.timelineHours, now.hour - 1))
end

local function format_timeline_hour(hour)
  hour = hour % 24
  if use_12_hour_time_enabled() then
    local suffix = hour >= 12 and "PM" or "AM"
    local display = hour % 12
    if display == 0 then display = 12 end
    return string.format("%d %s", display, suffix)
  end
  return string.format("%02d:00", hour)
end

local function event_end_minutes(event)
  local label = tostring(event.durationLabel or "")
  if label == "ALL DAY" then return 1440 end
  local sh, sm, eh, em = label:match("^(%d%d?):(%d%d)%s*%-%s*(%d%d?):(%d%d)$")
  if sh then
    local labelStart = (tonumber(sh) * 60) + tonumber(sm)
    local labelEnd = (tonumber(eh) * 60) + tonumber(em)
    local duration = labelEnd - labelStart
    -- 12-hour labels omit AM/PM; derive the duration, then apply it to the
    -- event's canonical 24-hour sortTime so afternoon events remain in PM.
    if duration <= 0 then duration = duration + 720 end
    return event_minutes(event) + duration
  end
  return event_minutes(event) + 60
end

local function format_event_start_time(event)
  local minutes = event_minutes(event)
  local hour = math.floor(minutes / 60)
  local minute = minutes % 60
  if use_12_hour_time_enabled() then
    local displayHour = hour % 12
    if displayHour == 0 then displayHour = 12 end
    return string.format("%d:%02d", displayHour, minute)
  end
  return string.format("%02d:%02d", hour, minute)
end

local function event_text_color(color)
  local red, green, blue = tostring(color or ""):match("^(%d+),(%d+),(%d+),%d+$")
  if not red then return SKIN:GetVariable("TextColor") end
  local brightness = (tonumber(red) * 0.299) + (tonumber(green) * 0.587) + (tonumber(blue) * 0.114)
  if brightness >= 145 then return "23,24,24,255" end
  return SKIN:GetVariable("TextColor")
end

local function update_timeline()
  local startMinute = state.timelineStartHour * 60
  local endMinute = startMinute + (state.timelineHours * 60)
  for index = 1, 8 do
    set_var("TimelineLabel" .. index, format_timeline_hour(state.timelineStartHour + index - 1))
  end

  -- Build and lay out the entire selected day before clipping it to the
  -- currently scrolled hours.  Otherwise an event just above/below the
  -- viewport disappears from the overlap calculation and makes the remaining
  -- blocks jump horizontally while scrolling.
  local allEntries = {}
  local allDayTitles = {}
  for _, event in ipairs(visible_events()) do
    local start = event_minutes(event)
    local ending = event_end_minutes(event)
    if event.durationLabel == "ALL DAY" then
      table.insert(allDayTitles, ascii_only(event.title))
    else
      table.insert(allEntries, { event = event, start = start, ending = ending })
    end
  end

  if #allDayTitles > 0 then
    set_var("AllDayText", "ALL DAY | " .. table.concat(allDayTitles, " | "))
    if state.view == "day" then
      SKIN:Bang("!ShowMeter", "MeterAllDayBackground")
      SKIN:Bang("!ShowMeter", "MeterAllDayText")
    end
  else
    SKIN:Bang("!HideMeter", "MeterAllDayBackground")
    SKIN:Bang("!HideMeter", "MeterAllDayText")
  end

  table.sort(allEntries, function(a, b)
    if a.start ~= b.start then return a.start < b.start end
    return a.ending > b.ending
  end)

  local position = 1
  while position <= #allEntries do
    local groupStart = position
    local groupEnd = allEntries[position].ending
    position = position + 1
    while position <= #allEntries and allEntries[position].start < groupEnd do
      if allEntries[position].ending > groupEnd then groupEnd = allEntries[position].ending end
      position = position + 1
    end
    local columnEnds, columns = {}, 0
    for i = groupStart, position - 1 do
      local column = 1
      while columnEnds[column] and columnEnds[column] > allEntries[i].start do column = column + 1 end
      columnEnds[column] = allEntries[i].ending
      allEntries[i].column = column
      if column > columns then columns = column end
    end
    for i = groupStart, position - 1 do allEntries[i].columns = columns end
  end

  local entries = {}
  for _, entry in ipairs(allEntries) do
    if entry.ending > startMinute and entry.start < endMinute then
      table.insert(entries, entry)
    end
  end

  update_timeline_now_indicator()

  for slot = 1, state.timelineSlots do
    local entry = entries[slot]
    if entry then
      local clippedStart = math.max(entry.start, startMinute)
      local clippedEnd = math.min(entry.ending, endMinute)
      local relativeStart = (clippedStart - startMinute) / 60
      local height = math.max(8, math.floor(((clippedEnd - clippedStart) / 60) * state.timelinePixelsPerHour) - 1)
      local columnWidth = ((tonumber(SKIN:GetVariable("PanelWidth")) or 430) - 94) / entry.columns
      local x = 76 + ((entry.column - 1) * columnWidth)
      local color = tostring(entry.event.color or "")
      if not color:match("^%d+,%d+,%d+,%d+$") then color = SKIN:GetVariable("RowColor") end
      local eventY = math.floor(state.timelineTopY + (relativeStart * state.timelinePixelsPerHour))
      set_var("DayEvent" .. slot .. "X", math.floor(x))
      set_var("DayEvent" .. slot .. "Y", eventY)
      set_var("DayEvent" .. slot .. "W", math.max(38, math.floor(columnWidth - 4)))
      set_var("DayEvent" .. slot .. "H", height)
      set_var("DayEvent" .. slot .. "Color", color)
      local titleMeter = "MeterDayEventTitle" .. slot
      local timeMeter = "MeterDayEventTime" .. slot
      local action = '[!CommandMeasure MeasureScript "ShowEventDetails(' .. slot .. ')"]'
      state.timelineSlotEvents[slot] = entry.event
      SKIN:Bang("!SetOption", "MeterDayEvent" .. slot, "LeftMouseUpAction", action)
      SKIN:Bang("!SetOption", titleMeter, "LeftMouseUpAction", action)
      SKIN:Bang("!SetOption", timeMeter, "LeftMouseUpAction", action)
      local textColor = event_text_color(color)
      local compactTextNudge = tonumber(SKIN:GetVariable("TimelineCompactTextNudgeY")) or 0
      SKIN:Bang("!SetOption", titleMeter, "FontColor", textColor)
      SKIN:Bang("!SetOption", timeMeter, "FontColor", textColor)
      if height < 20 then
        local textHeight = 12
        local offset = math.max(0, math.floor((height - textHeight) / 2) + compactTextNudge)
        SKIN:Bang("!SetOption", titleMeter, "FontSize", "7")
        SKIN:Bang("!SetOption", titleMeter, "StringStyle", "Bold")
        SKIN:Bang("!SetOption", titleMeter, "H", tostring(textHeight))
        set_var("DayEvent" .. slot .. "TextY", eventY + offset)
        set_var("DayEvent" .. slot .. "Title", ascii_only(entry.event.title))
        set_var("DayEvent" .. slot .. "Time", "")
      elseif height < 44 then
        local textHeight = 16
        local offset = math.max(1, math.floor((height - textHeight) / 2) + compactTextNudge)
        SKIN:Bang("!SetOption", titleMeter, "FontSize", "9")
        SKIN:Bang("!SetOption", titleMeter, "StringStyle", "Normal")
        SKIN:Bang("!SetOption", titleMeter, "H", tostring(textHeight))
        set_var("DayEvent" .. slot .. "TextY", eventY + offset)
        set_var("DayEvent" .. slot .. "Title", format_event_start_time(entry.event) .. "  " .. ascii_only(entry.event.title))
        set_var("DayEvent" .. slot .. "Time", "")
      else
        SKIN:Bang("!SetOption", titleMeter, "FontSize", "11")
        SKIN:Bang("!SetOption", titleMeter, "StringStyle", "Normal")
        SKIN:Bang("!SetOption", titleMeter, "H", "20")
        set_var("DayEvent" .. slot .. "TextY", eventY + 4)
        set_var("DayEvent" .. slot .. "Title", ascii_only(entry.event.title))
        set_var("DayEvent" .. slot .. "Time", event_duration_label(entry.event))
      end
      set_timeline_meter_visibility(slot, state.view == "day")
    else
      state.timelineSlotEvents[slot] = nil
      set_timeline_meter_visibility(slot, false)
    end
  end
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
  update_details_visibility()
end

update_settings_visibility = function()
  if state.settingsOpen then
    SKIN:Bang("!ShowMeter", "MeterSettingsOverlay")
    SKIN:Bang("!ShowMeter", "MeterSettingsTitle")
    SKIN:Bang("!ShowMeter", "MeterSettingsCopy")
    SKIN:Bang("!ShowMeter", "MeterSettingsTimeFormat")
    SKIN:Bang("!ShowMeter", "MeterSettingsSetup")
    SKIN:Bang("!ShowMeter", "MeterSettingsBack")
    SKIN:Bang("!ShowMeter", "MeterSettingsSyncStatus")
    SKIN:Bang("!HideMeter", "MeterNowIndicator")
    SKIN:Bang("!HideMeter", "MeterNowIndicatorText")
  else
    SKIN:Bang("!HideMeter", "MeterSettingsOverlay")
    SKIN:Bang("!HideMeter", "MeterSettingsTitle")
    SKIN:Bang("!HideMeter", "MeterSettingsCopy")
    SKIN:Bang("!HideMeter", "MeterSettingsTimeFormat")
    SKIN:Bang("!HideMeter", "MeterSettingsSetup")
    SKIN:Bang("!HideMeter", "MeterSettingsBack")
    SKIN:Bang("!HideMeter", "MeterSettingsSyncStatus")
    update_timeline_now_indicator()
  end
end

update_details_visibility = function()
  local meters = {
    "MeterDetailsOverlay", "MeterDetailsTitle", "MeterDetailsTime",
    "MeterDetailsMeta", "MeterDetailsBody", "MeterDetailsClose", "MeterDetailsCloseHit"
  }
  for _, meter in ipairs(meters) do
    SKIN:Bang(state.detailsOpen and "!ShowMeter" or "!HideMeter", meter)
  end
  if state.detailsOpen then
    SKIN:Bang("!HideMeter", "MeterNowIndicator")
    SKIN:Bang("!HideMeter", "MeterNowIndicatorText")
  elseif not state.settingsOpen then
    update_timeline_now_indicator()
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
  elseif source == "google-ical" then
    status = "Google iCal feeds"
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

visible_events = function()
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
  if state.view == "day" then
    update_timeline()
    return
  end
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
  state.detailsOpen = false
  set_var("DetailsHidden", 1)
  rootSkinPath = normalize_root_skin_path(SKIN:GetVariable("CURRENTPATH"))
  cacheFilePath = rootSkinPath .. "@Resources\\Data\\CalendarCache.lua"
  configFilePath = rootSkinPath .. "tools\\IcalCalendar.config.json"
  flyoutMarkerPath = rootSkinPath .. "tools\\FlyoutOpen.marker"
  state.visibleRows = tonumber(SKIN:GetVariable("VisibleRows")) or 5
  state.timelineSlots = tonumber(SKIN:GetVariable("TimelineSlotCount")) or state.timelineSlots
  write_text_file(flyoutMarkerPath, "open")
  if state.expanded then
    set_var("PanelX", SKIN:GetVariable("ExpandedPanelX"))
  else
    set_var("PanelX", SKIN:GetVariable("CollapsedPanelX"))
  end
  update_details_visibility()
  if not load_events() then
    show_error("Could not load " .. cacheFilePath)
    return
  end

  update_time_format_label()
  update_panel_visibility()
  update_settings_visibility()
  update_tab_colors()
  set_day_view_visibility(state.view == "day")
  update_date_text()
  position_timeline_near_now()
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
  state.detailsOpen = false
  set_var("DetailsHidden", 1)
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

function ShowEventDetails(slot)
  local event = state.timelineSlotEvents[tonumber(slot)]
  if not event then return end
  state.detailsOpen = true
  set_var("DetailsTitle", wrap_text(ascii_only(event.title), 28))
  set_var("DetailsTime", ascii_only(date_label({ wday = os.date("*t", event_timestamp(event)).wday, month = event.month, day = event.day }) .. " | " .. event_duration_label(event)))
  set_var("DetailsMeta", ascii_only(event.meta))
  set_var("DetailsBody", ascii_only(event.details ~= "" and event.details or "No additional event details are available."))
  set_var("DetailsHidden", 0)
  update_details_visibility()
  redraw()
end

function HideEventDetails()
  state.detailsOpen = false
  set_var("DetailsHidden", 1)
  update_details_visibility()
  update_rows()
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
  if state.view == "day" then
    position_timeline_near_now()
  end
  update_tab_colors()
  set_day_view_visibility(state.view == "day")
  update_rows()
  redraw()
end

function ShowDayView()
  if state.view == "day" then
    position_timeline_near_now()
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
  if state.view == "day" then
    state.timelineStartHour = math.max(0, math.min(24 - state.timelineHours, state.timelineStartHour + tonumber(delta)))
    update_timeline()
    redraw()
    return
  end
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
  SKIN:Bang("!DeactivateConfig", "rainmeter-gcal\\Flyout")
end

function Update()
  maybe_auto_jump_to_now()
  -- Update the red current-time marker on minute boundaries without moving a
  -- timeline the user has manually scrolled.
  local minuteKey = current_minute_key()
  if state.lastNowIndicatorMinuteKey ~= minuteKey then
    state.lastNowIndicatorMinuteKey = minuteKey
    update_timeline_now_indicator()
    redraw()
  end
  return ""
end
