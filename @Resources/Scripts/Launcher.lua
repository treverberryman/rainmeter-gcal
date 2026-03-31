local flyoutConfig = "rainmeter-gcal-flyout"
local flyoutMarkerPath = nil

local function read_text_file(path)
  local file = io.open(path, "r")
  if not file then
    return nil
  end

  local contents = file:read("*a")
  file:close()
  return contents
end

local function delete_file(path)
  if not path or path == "" then
    return
  end

  os.remove(path)
end

local function flyout_is_open()
  return read_text_file(flyoutMarkerPath) ~= nil
end

local function current_icon_position()
  local x = tonumber(SKIN:GetVariable("CURRENTCONFIGX") or "")
  local y = tonumber(SKIN:GetVariable("CURRENTCONFIGY") or "")

  if not x then
    x = SKIN:GetX()
  end

  if not y then
    y = SKIN:GetY()
  end

  return x or 0, y or 0
end

local function current_workarea()
  local x = tonumber(SKIN:GetVariable("WORKAREAX") or "") or 0
  local y = tonumber(SKIN:GetVariable("WORKAREAY") or "") or 0
  local width = tonumber(SKIN:GetVariable("WORKAREAWIDTH") or "") or 1920
  local height = tonumber(SKIN:GetVariable("WORKAREAHEIGHT") or "") or 1080
  return x, y, width, height
end

local function move_flyout()
  local iconX, iconY = current_icon_position()
  local workX, workY, workWidth, workHeight = current_workarea()
  local collapsedSize = tonumber(SKIN:GetVariable("CollapsedSize") or "74")
  local flyoutWidth = tonumber(SKIN:GetVariable("PanelWidth") or "372")
  local flyoutHeight = tonumber(SKIN:GetVariable("PanelHeight") or "514")
  local gap = 18

  local x = iconX + tonumber(SKIN:GetVariable("ExpandedPanelX") or "92")
  if x + flyoutWidth > workX + workWidth then
    x = iconX - flyoutWidth - gap
  end
  if x < workX then
    x = workX
  end

  local y = iconY
  if y + flyoutHeight > workY + workHeight then
    y = (workY + workHeight) - flyoutHeight
  end
  if y < workY then
    y = workY
  end

  if flyoutWidth <= (workWidth - collapsedSize - gap) and x <= iconX and (x + flyoutWidth + gap) > iconX then
    x = math.max(workX, iconX - flyoutWidth - gap)
  end

  SKIN:Bang("!Move", tostring(x), tostring(y), flyoutConfig)
end

function Initialize()
  flyoutMarkerPath = SKIN:GetVariable("CURRENTPATH") .. "tools\\FlyoutOpen.marker"
end

function Update()
  if flyout_is_open() then
    move_flyout()
  end
  return ""
end

function OpenFlyout()
  if flyout_is_open() then
    delete_file(flyoutMarkerPath)
    SKIN:Bang("!DeactivateConfig", flyoutConfig)
    return
  end

  SKIN:Bang("!ActivateConfig", flyoutConfig, "Flyout.ini")
  move_flyout()
end
