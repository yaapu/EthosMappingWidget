--
-- A FRSKY SPort/FPort/FPort2 and TBS CRSF telemetry widget for the Ethos OS
-- based on ArduPilot's passthrough telemetry protocol
--
-- Author: Alessandro Apostoli, https://github.com/yaapu
--
-- This program is free software; you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation; either version 3 of the License, or
-- (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY, without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with this program; if not, see <http://www.gnu.org/licenses>.


local function getTime()
  return os.clock()*100 -- 1/100th
end

local status = nil
local libs = nil

local drawLib = {}
local bitmaps = {}

local yawRibbonPoints = {"N",nil,"NE",nil,"E",nil,"SE",nil,"S",nil,"SW",nil,"W",nil,"NW",nil}

--[[
function drawLib.drawTopBar(widget)
  lcd.color(status.colors.barBackground)
  lcd.pen(SOLID)
  lcd.drawFilledRectangle(0,0,LCD_W,36)

  -- flight time
  drawLib.drawText(LCD_W, 0, model.getTimer(YAAPU_TIMER):valueString(), FONT_XL, status.colors.barText, RIGHT)
  -- flight mode
  if status.strFlightMode ~= nil then
    drawLib.drawText(0, 0, status.strFlightMode, FONT_XL, status.colors.barText, LEFT)
  end

  -- gps status, draw coordinatyes if good at least once
  if status.telemetry.lon ~= nil and status.telemetry.lat ~= nil then
    drawLib.drawText(630, -4, status.telemetry.strLat, FONT_STD, status.colors.barText, RIGHT)
    drawLib.drawText(630, 14, status.telemetry.strLon, FONT_STD, status.colors.barText, RIGHT)
  end
  -- gps status
  local hdop = status.telemetry.gpsHdopC
  local strStatus = status.gpsStatuses[status.telemetry.gpsStatus]
  local prec = 0
  local blink = true
  local flags = BLINK
  local mult = 0.1

  if status.telemetry.gpsStatus  > 2 then
    blink = false
    if status.telemetry.homeAngle ~= -1 then
      prec = 1
    end
    if hdop > 999 then
      hdop = 999
    end
    drawLib.drawNumber(450,0, hdop*mult, prec, FONT_XL, status.colors.barText, LEFT, blink)
    -- SATS
    drawLib.drawText(448,10, strStatus, FONT_STD, status.colors.barText, RIGHT)

    if status.telemetry.numSats == 15 then
      drawLib.drawNumber(300,0, status.telemetry.numSats, 0, FONT_XL, status.colors.barText)
      drawLib.drawText(320,0, "+", FONT_STD, status.colors.white)
    else
      drawLib.drawNumber(300,0, status.telemetry.numSats, 0, FONT_XL, status.colors.barText)
    end
    drawLib.drawBitmap(270,0, "gpsicon")
  elseif status.telemetry.gpsStatus == 0 then
    drawLib.drawBlinkBitmap(322,0, "nogpsicon")
  else
    drawLib.drawBlinkBitmap(322,0, "nolockicon")
  end
end
--]]

function drawLib.drawStatusBar(widget,maxRows)
  local yDelta = 2+maxRows*20
  lcd.color(status.colors.barBackground)
  lcd.pen(SOLID)
  lcd.drawFilledRectangle(0,320-yDelta,480, yDelta)
  -- messages
  lcd.font(FONT_STD)
  local offset = math.min(maxRows,#status.messages+1)
  for i=0,offset-1 do
    local msg = status.messages[(status.messageCount + i - offset) % (#status.messages+1)]
    lcd.color(status.mavSeverity[msg[2]][2])
    lcd.drawText(1,320 - yDelta + (19*i), msg[1])
  end
end

function drawLib.drawFailsafe(widget)
  if status.telemetry.ekfFailsafe > 0 then
    drawLib.drawBlinkBitmap(244, 120, "ekffailsafe")
  elseif status.telemetry.battFailsafe > 0 then
    drawLib.drawBlinkBitmap(244, 120, "battfailsafe")
  elseif status.telemetry.failsafe > 0 then
    drawLib.drawBlinkBitmap(244, 120, "failsafe")
  end
end


function drawLib.drawNoTelemetryData(widget)
  if not libs.utils.telemetryEnabled() then
    lcd.color(RED)
    lcd.drawFilledRectangle(40,70, 400, 140)
    lcd.color(WHITE)
    lcd.drawRectangle(40,70, 400, 140,3)
    lcd.font(FONT_XXL)
    lcd.drawText(240, 87, "NO TELEMETRY", CENTERED)
    lcd.font(FONT_STD)
    lcd.drawText(240, 152, "Yaapu Mapping Widget 1.0.0 dev".."("..'d1f1063'..")", CENTERED)
  end
end

function drawLib.drawNoGPSData(widget)
  lcd.color(RED)
  lcd.drawFilledRectangle(40,70, 400, 140)
  lcd.color(WHITE)
  lcd.drawRectangle(40,70, 400, 140,3)
  lcd.font(FONT_XXL)
  lcd.drawText(240, 87, "...waiting for GPS", CENTERED)
  lcd.font(FONT_STD)
  lcd.drawText(240, 152, "Yaapu Mapping Widget 1.0.0 dev".."("..'d1f1063'..")", CENTERED)
end

function drawLib.drawFenceStatus(x,y)
  if status.telemetry.fencePresent == 0 then
    return x
  end
  if status.telemetry.fenceBreached == 1 then
    drawLib.drawBlinkBitmap(x,y,"fence_breach")
    return x+21
  end
  drawLib.drawBitmap(x,y,"fence_ok")
  return x+21
end

function drawLib.drawTerrainStatus(x,y)
  if status.status.terrainEnabled == 0 then
    return x
  end
  if status.telemetry.terrainUnhealthy == 1 then
    drawLib.drawBlinkBitmap(x,y,"terrain_error")
    return x+21
  end
  drawLib.drawBitmap(x,y,"terrain_ok")
  return x+21
end

function drawLib.drawText(x, y, txt, font, color, flags, blink)
  lcd.font(font)
  lcd.color(color)
  if status.blinkon == true or blink == nil or blink == false then
    lcd.drawText(x, y, txt, flags)
  end
end

function drawLib.drawNumber(x, y, num, precision, font, color, flags, blink)
  lcd.font(font)
  lcd.color(color)
  if status.blinkon == true or blink == nil or blink == false then
    lcd.drawNumber(x, y, num, nil, precision, flags)
  end
end

--[[
  based on olliw's improved version over mine :-)
  https://github.com/olliw42/otxtelemetry
--]]
function drawLib.drawCompassRibbon(y,widget,width,xMin,xMax)
  local minY = y+1
  local heading = status.telemetry.yaw
  local minX = xMin
  local maxX = xMax
  local midX = (xMax + xMin)/2
  local tickNo = 4 --number of ticks on one side
  local stepCount = (maxX - minX -24)/(2*tickNo)
  local closestHeading = math.floor(heading/22.5) * 22.5
  local closestHeadingX = midX + (closestHeading - heading)/22.5 * stepCount
  local tickIdx = (closestHeading/22.5 - tickNo) % 16
  local tickX = closestHeadingX - tickNo*stepCount
  lcd.pen(SOLID)
  lcd.color(status.colors.white)
  lcd.font(FONT_BOLD)
  for i = 1,10 do
      if tickX >= minX and tickX < maxX then
          if yawRibbonPoints[tickIdx+1] == nil then
              --lcd.drawLine(tickX, minY, tickX, y+10)
              lcd.drawFilledRectangle(tickX-1,minY, 2, 10)
          else
              lcd.drawText(tickX, minY-3, yawRibbonPoints[tickIdx+1], CENTERED)
          end
      end
      tickIdx = (tickIdx + 1) % 16
      tickX = tickX + stepCount
  end
  -- home icon
  local homeOffset = 0
  local angle = status.telemetry.homeAngle - status.telemetry.yaw
  if angle < 0 then angle = angle + 360 end
  if angle > 270 or angle < 90 then
    homeOffset = ((angle + 90) % 180)/180  * width * 0.9
  elseif angle >= 90 and angle < 180 then
    homeOffset = width * 0.9
  end
  drawLib.drawHomeIcon(xMin + homeOffset -5,minY + 27)
  -- text box
  lcd.color(status.colors.black)
  lcd.drawFilledRectangle(midX - 31, minY-1, 60, 32)
  drawLib.drawNumber(midX,minY-2,heading,0,FONT_XL,status.colors.white,CENTERED)
end


function drawLib.drawPanelSensor(x,y,value,prec,label,unit,font,lfont,ufont,color,lcolor,rightAlign,blink)
  local w,h
  lcd.font(font)
  if value == nil then
    value = 0
    w,h = lcd.getTextSize(value)
  else
    w,h = lcd.getTextSize(string.format("%."..prec.."f",value))
  end

  lcd.font(lfont)
  local lw,lh = lcd.getTextSize(label)
  lcd.font(ufont)
  local uw,uh = lcd.getTextSize(unit)

  if rightAlign == true then
    drawLib.drawText(x,y, label, lfont, lcolor, RIGHT)
    drawLib.drawText(x,y+0.7*lh+0.85*h-uh, unit, ufont, color, RIGHT)
    drawLib.drawNumber(x-uw,y+0.7*lh, value, prec, font, color, RIGHT, blink)
  else
    drawLib.drawText(x,y, label, lfont, lcolor, LEFT)
    drawLib.drawNumber(x,y+0.7*lh, value, prec, font, color, LEFT, blink)
    drawLib.drawText(x+w,y+0.7*lh+0.85*h-uh, unit, ufont, color, LEFT)
  end
end


function drawLib.drawTopBarSensor(widget,x,sensor,label)
  local offset = 0
  if sensor ~= nil then
    lcd.font(FONT_L)
    local w,h = lcd.getTextSize(sensor:stringValue())
    drawLib.drawText(x-w-2, 6, label == nil and sensor:name() or label, FONT_XS, status.colors.barText, RIGHT)
    drawLib.drawText(x-w, 0, sensor:stringValue(), FONT_L, status.colors.barText, LEFT)
    lcd.font(FONT_XS)
    local w2,h2 = lcd.getTextSize(sensor:name())
    return w + w2 + 4
  else
    drawLib.drawText(x, 0, "---", FONT_L, status.colors.barText, RIGHT)
    return 100
  end
end


function drawLib.drawTopBar(widget)
  lcd.color(status.colors.barBackground)
  lcd.pen(SOLID)
  lcd.drawFilledRectangle(0, 0, 480,14)
  drawLib.drawText(0, -2, status.modelString ~= nil and status.modelString or model.name(), FONT_L, status.colors.barText, LEFT)
  local offset = drawLib.drawTopBarSensor(widget, 480, system.getSource({category=CATEGORY_SYSTEM, member=MAIN_VOLTAGE,options=0}), "TX") + -50
  offset = offset + drawLib.drawTopBarSensor(widget, 480 - offset, status.conf.linkQualitySource) + 3
  if status.conf.userSensor1 ~= nil and status.conf.userSensor1:name()  ~= "---" then
    source = status.conf.userSensor1
    offset = offset + drawLib.drawTopBarSensor(widget, 480-offset, status.conf.userSensor1) + 3
  end
  if status.conf.userSensor2 ~= nil  and status.conf.userSensor2:name() ~= "---" then
    offset = offset + drawLib.drawTopBarSensor(widget, 480-offset, status.conf.userSensor2) + 3
  end
  if status.conf.userSensor3 ~= nil and status.conf.userSensor3:name() ~= "---" then
    offset = offset + drawLib.drawTopBarSensor(widget, 480-offset, status.conf.userSensor3) + 3
  end
end

function drawLib.drawRArrow(x,y,r,angle,color)
  local ang = math.rad(angle - 90)
  local x1 = x + r * math.cos(ang)
  local y1 = y + r * math.sin(ang)

  ang = math.rad(angle - 90 + 150)
  local x2 = x + r * math.cos(ang)
  local y2 = y + r * math.sin(ang)

  ang = math.rad(angle - 90 - 150)
  local x3 = x + r * math.cos(ang)
  local y3 = y + r * math.sin(ang)
  ang = math.rad(angle - 270)
  local x4 = x + r * 0.5 * math.cos(ang)
  local y4 = y + r * 0.5 *math.sin(ang)
  --
  lcd.pen(SOLID)
  lcd.color(color)
  lcd.drawLine(x1,y1,x2,y2)
  lcd.drawLine(x1,y1,x3,y3)
  lcd.drawLine(x2,y2,x4,y4)
  lcd.drawLine(x3,y3,x4,y4)
end

-- initialize up to 5 bars
local barMaxValues = {}
local barAvgValues = {}
local barSampleCounts = {}

local function initMap(map,name)
  if map[name] == nil then
    map[name] = 0
  end
end

function drawLib.updateBar(name, value)
  -- init
  initMap(barSampleCounts,name)
  initMap(barMaxValues,name)
  initMap(barAvgValues,name)

  -- update metadata
  barSampleCounts[name] = barSampleCounts[name]+1
  barMaxValues[name] = math.max(value,barMaxValues[name])
  -- weighted average on 10 samples
  barAvgValues[name] = barAvgValues[name]*0.9 + value*0.1
end

-- draw an horizontal dynamic bar with an average red pointer of the last 5 samples
function drawLib.drawBar(name, x, y, w, h, color, value, font)
  drawLib.updateBar(name, value)

  lcd.color(status.colors.white)
  lcd.pen(SOLID)
  lcd.drawFilledRectangle(x,y,w,h)

  -- normalize percentage relative to MAX
  local perc = 0
  local avgPerc = 0
  if barMaxValues[name] > 0 then
    perc = value/barMaxValues[name]
    avgPerc = barAvgValues[name]/barMaxValues[name]
  end
  lcd.color(color)
  lcd.drawFilledRectangle(math.max(x,x+w-perc*w),y+1,math.min(w,perc*w),h-2)
  lcd.color(status.colors.red)

  lcd.drawLine(x+w-avgPerc*(w-2),y+1,x+w-avgPerc*(w-2),y+h-2)
  lcd.drawLine(1+x+w-avgPerc*(w-2),y+1,1+x+w-avgPerc*(w-2),y+h-2)
  drawLib.drawNumber(x+w-2,y,value,0,font,status.colors.black,RIGHT)
  -- border
  lcd.drawRectangle(x,y,w,h)
end

function drawLib.drawMessages(widget)
  local row = 0
  local offsetStart = status.messageOffset
  local offsetEnd = math.min(status.messageCount-1, status.messageOffset + SCREEN_MESSAGES - 1)

  lcd.font(FONT_STD)
  for i=offsetStart,offsetEnd  do
    lcd.color(status.mavSeverity[status.messages[i % MAX_MESSAGES][2]][2])
    lcd.drawText(0, 36 + 18*row, status.messages[i % MAX_MESSAGES][1])
    row = row + 1
  end
end

function drawLib.resetBacklightTimeout()
  print("RESET BACKLIGHT")
  system.resetBacklightTimeout()
end

function drawLib.getBitmap(name)
  if bitmaps[name] == nil then
    bitmaps[name] = lcd.loadBitmap("/scripts/yaapumaps/bitmaps/"..name..".png")
  end
  return bitmaps[name]
end

function drawLib.unloadBitmap(name)
  if bitmaps[name] ~= nil then
    bitmaps[name] = nil
    -- force call to luaDestroyBitmap()
    collectgarbage()
    collectgarbage()
  end
end

function drawLib.drawBlinkRectangle(x,y,w,h,t)
  if status.blinkon == true then
      lcd.drawRectangle(x,y,w,h,t)
  end
end

function drawLib.drawBitmap(x, y, bitmap, w, h)
  lcd.drawBitmap(x, y, drawLib.getBitmap(bitmap), w, h)
end

function drawLib.drawBlinkBitmap(x, y, bitmap, w, h)
  if status.blinkon == true then
      lcd.drawBitmap(x, y, drawLib.getBitmap(bitmap), w, h)
  end
end

function drawLib.drawMinMaxBar(x, y, w, h, color, val, min, max, showValue)
  local range = max - min
  local value = math.min(math.max(val,min),max) - min
  local perc = value/range
  lcd.color(status.colors.white)
  lcd.pen(SOLID)
  lcd.drawFilledRectangle(x,y,w,h)
  lcd.color(color)
  lcd.pen(SOLID)
  lcd.drawRectangle(x,y,w,h,2)
  lcd.drawFilledRectangle(x,y,w*perc,h)
  lcd.color(status.colors.black)
  lcd.font(XL)
  if showValue == true then
    local strperc = string.format("%02d%%",math.floor(val+0.5))
    lcd.drawText(x+w/2, y, strperc, CENTERED)
  end
end


local CS_INSIDE = 0
local CS_LEFT = 1
local CS_RIGHT = 2
local CS_BOTTOM = 4
local CS_TOP = 8

function drawLib.computeOutCode(x,y,xmin,ymin,xmax,ymax)
    local code = CS_INSIDE; --initialised as being inside of hud
    if x < xmin then --to the left of hud
        code = code | CS_LEFT
    elseif x > xmax then --to the right of hud
        code = code | CS_RIGHT
    end
    if y < ymin then --below the hud
        code = code | CS_TOP
    elseif y > ymax then --above the hud
        code = code | CS_BOTTOM
    end
    return code
end

function drawLib.isInside(x,y,xmin,ymin,xmax,ymax)
  print("INSIDE",x,y,xmin,ymin,xmax,ymax)
  return drawLib.computeOutCode(x,y,xmin,ymin,xmax,ymax) == CS_INSIDE
end

--[[
-- Cohen–Sutherland clipping algorithm
-- https://en.wikipedia.org/wiki/Cohen%E2%80%93Sutherland_algorithm
function drawLib.drawLineWithClippingXY(x0, y0, x1, y1, xmin, ymin, xmax, ymax)
  -- compute outcodes for P0, P1, and whatever point lies outside the clip rectangle
  local outcode0 = computeOutCode(x0, y0, xmin, ymin, xmax, ymax);
  local outcode1 = computeOutCode(x1, y1, xmin, ymin, xmax, ymax);
  local accept = false;
  while (true) do
    if (outcode0 | outcode1) == CS_INSIDE then
      -- bitwise OR is 0: both points inside window; trivially accept and exit loop
      accept = true;
      break;
    elseif (outcode0 & outcode1) ~= CS_INSIDE then
      -- bitwise AND is not 0: both points share an outside zone (LEFT, RIGHT, TOP, BOTTOM)
      -- both must be outside window; exit loop (accept is false)
      break;
    else
      -- failed both tests, so calculate the line segment to clip
      -- from an outside point to an intersection with clip edge
      local x = 0
      local y = 0
      -- At least one endpoint is outside the clip rectangle; pick it.
      local outcodeOut = outcode0 ~= CS_INSIDE and outcode0 or outcode1
      -- No need to worry about divide-by-zero because, in each case, the
      -- outcode bit being tested guarantees the denominator is non-zero
      if outcodeOut & CS_BOTTOM  ~= CS_INSIDE then --point is above the clip window
        x = x0 + (x1 - x0) * (ymax - y0) / (y1 - y0)
        y = ymax
      elseif outcodeOut & CS_TOP  ~= CS_INSIDE then --point is below the clip window
        x = x0 + (x1 - x0) * (ymin - y0) / (y1 - y0)
        y = ymin
      elseif outcodeOut & CS_RIGHT  ~= CS_INSIDE then --point is to the right of clip window
        y = y0 + (y1 - y0) * (xmax - x0) / (x1 - x0)
        x = xmax
      elseif outcodeOut & CS_LEFT  ~= CS_INSIDE then --point is to the left of clip window
        y = y0 + (y1 - y0) * (xmin - x0) / (x1 - x0)
        x = xmin
      end
      -- Now we move outside point to intersection point to clip
      -- and get ready for next pass.
      if outcodeOut == outcode0 then
        x0 = x
        y0 = y
        outcode0 = computeOutCode(x0, y0, xmin, ymin, xmax, ymax)
      else
        x1 = x
        y1 = y
        outcode1 = computeOutCode(x1, y1, xmin, ymin, xmax, ymax)
      end
    end
  end
  if accept then
    lcd.drawLine(x0,y0,x1,y1)
  end
end
--]]

function drawLib.drawLineWithClippingXY(x0, y0, x1, y1, xmin, ymin, xmax, ymax)
  lcd.setClipping(xmin, ymin, xmax-xmin, ymax-ymin)
  lcd.drawLine(x0,y0,x1,y1)
  lcd.setClipping()
end

-- draw a line centered on (ox,oy) with angle and len, clipped
function drawLib.drawLineWithClipping(ox, oy, angle, len, xmin,ymin, xmax, ymax)
  local xx = math.cos(math.rad(angle)) * len * 0.5
  local yy = math.sin(math.rad(angle)) * len * 0.5

  local x0 = ox - xx
  local x1 = ox + xx
  local y0 = oy - yy
  local y1 = oy + yy

  drawLib.drawLineWithClippingXY(x0,y0,x1,y1,xmin,ymin,xmax,ymax)
end

function drawLib.drawArmingStatus(widget)
  -- armstatus
  if not libs.utils.failsafeActive(widget) and status.timerRunning == 0 then
    if status.telemetry.statusArmed == 1 then
      drawLib.drawBitmap( 244, 120, "armed")
    else
      drawLib.drawBlinkBitmap(244, 120, "disarmed")
    end
  end
end

function drawLib.drawHomeIcon(x,y)
  drawLib.drawBitmap(x,y,"minihomeorange")
end

function drawLib.drawWindArrow(x,y,r1,r2,arrow_angle, angle, skew, color)
  local a = math.rad(angle - 90)
  local ap = math.rad(angle + arrow_angle/2 - 90)
  local am = math.rad(angle - arrow_angle/2 - 90)

  local x1 = x + r1 * math.cos(a) * skew
  local y1 = y + r1 * math.sin(a)
  local x2 = x + r2 * math.cos(ap) * skew
  local y2 = y + r2 * math.sin(ap)
  local x3 = x + r2 * math.cos(am) * skew
  local y3 = y + r2 * math.sin(am)

  lcd.color(color)
  lcd.pen(SOLID)
  lcd.drawLine(x1,y1,x2,y2)
  lcd.drawLine(x1,y1,x3,y3)
end

function drawLib.init(param_status, param_libs)
  status = param_status
  libs = param_libs
  return drawLib
end

return drawLib
