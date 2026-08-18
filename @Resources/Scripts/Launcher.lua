local flyoutConfig = "rainmeter-gcal\\Flyout"
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

local function clamp(value, minimum, maximum)
  if maximum < minimum then
    return minimum
  end

  if value < minimum then
    return minimum
  end
  if value > maximum then
    return maximum
  end
  return value
end

local function rectangles_overlap(ax, ay, aw, ah, bx, by, bw, bh)
  return ax < bx + bw and ax + aw > bx and ay < by + bh and ay + ah > by
end

local function move_flyout()
  local iconX, iconY = current_icon_position()
  local workX, workY, workWidth, workHeight = current_workarea()
  local collapsedSize = tonumber(SKIN:GetVariable("CollapsedSize") or "74")
  local flyoutWidth = tonumber(SKIN:GetVariable("PanelWidth") or "372")
  local flyoutHeight = tonumber(SKIN:GetVariable("PanelHeight") or "514")
  local gap = 18

  -- Position relative to the launcher rather than its old fixed offset.  The
  -- flyout is now much taller, so a fixed right/left placement can force it
  -- through the taskbar or back across the launcher near a screen edge.
  local workRight = workX + workWidth
  local workBottom = workY + workHeight
  local maxX = workRight - flyoutWidth
  local maxY = workBottom - flyoutHeight
  local centeredX = iconX + (collapsedSize - flyoutWidth) / 2
  local centeredY = iconY + (collapsedSize - flyoutHeight) / 2

  local candidates = {}
  local function add_candidate(name, rawX, rawY, priority)
    local x = clamp(rawX, workX, maxX)
    local y = clamp(rawY, workY, maxY)
    local overlap = rectangles_overlap(x, y, flyoutWidth, flyoutHeight, iconX, iconY, collapsedSize, collapsedSize)
    local fully_fits = rawX >= workX and rawX + flyoutWidth <= workRight
      and rawY >= workY and rawY + flyoutHeight <= workBottom

    table.insert(candidates, {
      name = name,
      x = x,
      y = y,
      overlap = overlap,
      fully_fits = fully_fits,
      priority = priority,
    })
  end

  -- The preferred vertical side changes at the middle of the work area; the
  -- preferred horizontal side does the same.  This makes each desktop corner
  -- open inward while leaving a gap around the launcher.
  local bottomHalf = iconY + collapsedSize / 2 >= workY + workHeight / 2
  local rightHalf = iconX + collapsedSize / 2 >= workX + workWidth / 2
  local aboveY = iconY - flyoutHeight - gap
  local belowY = iconY + collapsedSize + gap
  local leftX = iconX - flyoutWidth - gap
  local rightX = iconX + collapsedSize + gap

  if bottomHalf then
    add_candidate("above", centeredX, aboveY, 1)
    add_candidate(rightHalf and "left" or "right", rightHalf and leftX or rightX, centeredY, 2)
    add_candidate(rightHalf and "right" or "left", rightHalf and rightX or leftX, centeredY, 3)
    add_candidate("below", centeredX, belowY, 4)
  else
    add_candidate("below", centeredX, belowY, 1)
    add_candidate(rightHalf and "left" or "right", rightHalf and leftX or rightX, centeredY, 2)
    add_candidate(rightHalf and "right" or "left", rightHalf and rightX or leftX, centeredY, 3)
    add_candidate("above", centeredX, aboveY, 4)
  end

  local chosen = nil
  for _, candidate in ipairs(candidates) do
    if candidate.fully_fits and not candidate.overlap then
      chosen = candidate
      break
    end
  end

  -- On unusually small displays, preserve as much of the flyout as possible
  -- and still avoid covering the launcher whenever a non-overlapping option
  -- exists.
  if not chosen then
    for _, candidate in ipairs(candidates) do
      if not candidate.overlap then
        chosen = candidate
        break
      end
    end
  end
  chosen = chosen or candidates[1]

  SKIN:Bang("!Move", tostring(math.floor(chosen.x + 0.5)), tostring(math.floor(chosen.y + 0.5)), flyoutConfig)
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
