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

local hudLib = {}

local R2 = 18.5

local HUD_W = 292 --340
local HUD_H = 198 --160
local HUD_MIN_X = (800 - HUD_W)/2
local HUD_MIN_Y = 36
local HUD_MAX_X = HUD_MIN_X + HUD_W
local HUD_MAX_Y = HUD_MIN_Y + HUD_H
local HUD_MID_X = HUD_MIN_X + HUD_W/2 - 6
local HUD_MID_Y = HUD_MIN_Y + HUD_H/2

local function unclip()
  lcd.setClipping()
end

local function clipHud(reset)
  lcd.setClipping(HUD_MIN_X, HUD_MIN_Y, HUD_W, HUD_H)
end

local function clipCompassRibbon()
  lcd.setClipping(HUD_MIN_X, HUD_MIN_Y, 280, 32)
end

local function drawFilledRectangle(x,y,w,h)
    if w > 0 and h > 0 then
      lcd.drawFilledRectangle(x,y,w,h)
    end
end

function hudLib.drawHud(widget)
  local r = -status.telemetry.roll
  local cx,cy,dx,dy
  local scale = 1.85 -- 1.85
  -----------------------
  -- artificial horizon
  -----------------------
  -- no roll ==> segments are vertical, offsets are multiples of R2
  if ( status.telemetry.roll == 0 or math.abs(status.telemetry.roll) == 180) then
    dx=0
    dy=status.telemetry.pitch * scale
    cx=0
    cy=R2
  else
    -- center line offsets
    dx = math.cos(math.rad(90 - r)) * -status.telemetry.pitch
    dy = math.sin(math.rad(90 - r)) * status.telemetry.pitch * scale
    -- 1st line offsets
    cx = math.cos(math.rad(90 - r)) * R2
    cy = math.sin(math.rad(90 - r)) * R2
  end
  local rollX = math.floor(HUD_MID_X) -- math.floor(HUD_X + HUD_WIDTH/2)
  -----------------------
  -- dark color for "ground"
  -----------------------
  -- 140x90
  local minX = HUD_MIN_X
  local minY = HUD_MIN_Y

  local maxX = HUD_MAX_X
  local maxY = HUD_MAX_Y

  local ox = HUD_MID_X + dx
  local oy = HUD_MID_Y + dy

  -- background
  --lcd.color(120,200,235)
  lcd.color(status.colors.hudSky)
  lcd.pen(SOLID)
  lcd.drawFilledRectangle(HUD_MIN_X, HUD_MIN_Y, HUD_W, HUD_H)
  --libs.drawLib.drawBitmap(100,18, "hud_bg_280x134")

  -- HUD
  --lcd.color(0x63, 0x30, 0x00) -- brown
  lcd.color(status.colors.hudTerrain) -- green
  lcd.pen(SOLID)

  -- angle of the line passing on point(ox,oy)
  local angle = math.tan(math.rad(-status.telemetry.roll))
  -- prevent divide by zero
  if status.telemetry.roll == 0 then
    drawFilledRectangle(minX,math.max(minY,dy+minY+(maxY-minY)/2),maxX-minX,math.min(maxY-minY,(maxY-minY)/2-dy+(math.abs(dy) > 0 and 1 or 0)))
  elseif math.abs(status.telemetry.roll) >= 180 then
    drawFilledRectangle(minX,minY,maxX-minX,math.min(maxY-minY,(maxY-minY)/2+dy))
  else
    -- HUD drawn using horizontal bars of height 2
    -- true if flying inverted
    local inverted = math.abs(status.telemetry.roll) > 90
    -- true if part of the hud can be filled in one pass with a rectangle
    local fillNeeded = false
    local yRect = inverted and 0 or 800

    local step = 2
    local steps = (maxY - minY)/step - 1
    local yy = 0

    if 0 < status.telemetry.roll and status.telemetry.roll < 180 then
      for s=0,steps
      do
        yy = minY + s*step
        xx = ox + (yy-oy)/angle
        if xx >= minX and xx <= maxX then
          lcd.drawFilledRectangle(xx, yy, maxX-xx+1, step)
        elseif xx < minX then
          yRect = inverted and math.max(yy,yRect)+step or math.min(yy,yRect)
          fillNeeded = true
        end
      end
    elseif -180 < status.telemetry.roll and status.telemetry.roll < 0 then
      for s=0,steps
      do
        yy = minY + s*step
        xx = ox + (yy-oy)/angle
        if xx >= minX and xx <= maxX then
          lcd.drawFilledRectangle(minX, yy, xx-minX, step)
        elseif xx > maxX then
          yRect = inverted and math.max(yy,yRect)+step or math.min(yy,yRect)
          fillNeeded = true
        end
      end
    end

    if fillNeeded then
      local yMin = inverted and minY or yRect
      local height = inverted and yRect - minY or maxY-yRect
      lcd.drawFilledRectangle(minX, yMin, maxX-minX, height)
    end
  end

  -- parallel lines above and below horizon
  local linesMaxY = HUD_MAX_Y - 2   -- maxY-2
  local linesMinY = HUD_MIN_Y + 10  -- minY+10

  lcd.color(status.colors.hudLines)
  lcd.pen(DOTTED)
  -- +/- 90 deg
  for dist=1,5
  do
    libs.drawLib.drawLineWithClipping(rollX + dx - dist*cx,dy + HUD_MID_Y + dist*cy,r,(dist%2==0 and 80 or 40),HUD_MIN_X,linesMinY,HUD_MAX_X,linesMaxY)
    libs.drawLib.drawLineWithClipping(rollX + dx + dist*cx,dy + HUD_MID_Y - dist*cy,r,(dist%2==0 and 80 or 40),HUD_MIN_X,linesMinY,HUD_MAX_X,linesMaxY)
  end

  --[[
  -- horizon line
  lcd.color(160,160,160)
  lcd.pen(SOLID)
  libs.drawLib.drawLineWithClipping(rollX + dx,dy + HUD_MID_Y,r,200,HUD_MIN_X,linesMinY,HUD_MAX_X,linesMaxY)
  --]]
  -- hashmarks
  clipHud() -- tru
  local startY = minY
  local endY = maxY
  local step = 26
  -- hSpeed
  local roundHSpeed = math.floor((status.telemetry.hSpeed*status.conf.horSpeedMultiplier*0.1/5)+0.5)*5;
  local offset = math.floor((status.telemetry.hSpeed*status.conf.horSpeedMultiplier*0.1-roundHSpeed)*0.2*step);
  local ii = 0;
  local yy = 0
  lcd.color(status.colors.hudDashes)
  lcd.pen(SOLID)
  lcd.font(FONT_S)
  for j=roundHSpeed+20,roundHSpeed-20,-5
  do
      yy = startY + (ii*step) + offset - 14
      if yy >= startY and yy < endY then
        lcd.drawLine(HUD_MIN_X, yy+9, HUD_MIN_X+6, yy+9)
        lcd.drawNumber(HUD_MIN_X+9,  yy, j)
      end
      ii=ii+1;
  end
  -- altitude
  local roundAlt = math.floor((status.telemetry.homeAlt*status.conf.distUnitScale/5)+0.5)*5;
  offset = math.floor((status.telemetry.homeAlt*status.conf.distUnitScale-roundAlt)*0.2*step);
  ii = 0;
  yy = 0
  for j=roundAlt+20,roundAlt-20,-5
  do
      yy = startY + (ii*step) + offset - 14
      if yy >= startY and yy < endY then
        lcd.drawLine(518, yy+8, 524 , yy+8)
        libs.drawLib.drawNumber(516,  yy, j, 0, FONT_S, status.colors.hudDashes, RIGHT)
      end
      ii=ii+1;
  end
  unclip() --reset hud clipping
  -- compass ribbon
  clipCompassRibbon() -- set clipping
  libs.drawLib.drawCompassRibbon(minY,widget,300,minX,maxX-10)
  unclip() -- reset clipping
  -------------------------------------
  -- hud bitmap
  -------------------------------------
  --libs.drawLib.drawBitmap(minX, minY, "hud_340x160b")
  libs.drawLib.drawBitmap(minX, minY, "hud_298x198")

  if status.conf.enableWIND == true then
    libs.drawLib.drawWindArrow(HUD_MID_X,134,33,49,50,status.telemetry.trueWindAngle-status.telemetry.yaw, 1.3, status.colors.white);
    libs.drawLib.drawWindArrow(HUD_MID_X,134,38,49,50,status.telemetry.trueWindAngle-status.telemetry.yaw, 1.3, status.colors.white);
    libs.drawLib.drawWindArrow(HUD_MID_X,134,31,51,53,status.telemetry.trueWindAngle-status.telemetry.yaw, 1.3, status.colors.black);
    libs.drawLib.drawWindArrow(HUD_MID_X,134,40,51,53,status.telemetry.trueWindAngle-status.telemetry.yaw, 1.3, status.colors.black);
  end

  -------------------------------------
  -- vario
  -------------------------------------
  local varioMax = 5
  local varioSpeed = math.min(math.abs(0.1*status.telemetry.vSpeed),5)
  local varioH = varioSpeed/varioMax*78
  --varioH = varioH + (varioH > 0 and 1 or 0)
  if status.telemetry.vSpeed > 0 then
    varioY = 114 - varioH
  else
    varioY = 156
  end
  lcd.color(status.colors.yellow)
  lcd.drawFilledRectangle(528, varioY, 14, varioH)

  -------------------------------------
  -- left and right indicators on HUD
  -------------------------------------
  -- DATA
  -- altitude
  local homeAlt = libs.utils.getMaxValue(status.telemetry.homeAlt,MINMAX_ALT) * status.conf.distUnitScale
  local alt = homeAlt
  if status.terrainEnabled == 1 then
    alt = status.telemetry.heightAboveTerrain * status.conf.distUnitScale
    lcd.color(status.colors.black)
    lcd.drawFilledRectangle(446, 156, 80, 18)
  end

  if math.abs(alt) > 999 or alt < -99 then
    libs.drawLib.drawNumber(HUD_MAX_X-1, 114, alt, 0, FONT_XXL, status.colors.hudSideText, RIGHT)
    if status.terrainEnabled == 1 then
      libs.drawLib.drawNumber(HUD_MAX_X-12, 152, alt, 0, FONT_STD, status.colors.hudSideText, RIGHT)
    end
  elseif math.abs(alt) >= 10 then
    libs.drawLib.drawNumber(HUD_MAX_X-1, 114, alt, 0, FONT_XXL, status.colors.hudSideText, RIGHT)
    if status.terrainEnabled == 1 then
      libs.drawLib.drawNumber(HUD_MAX_X-12, 152, alt, 0, FONT_STD, status.colors.hudSideText, RIGHT)
    end
  else
    libs.drawLib.drawNumber(HUD_MAX_X-1, 114, alt, 1, FONT_XXL, status.colors.hudSideText, RIGHT)
    if status.terrainEnabled == 1 then
      libs.drawLib.drawNumber(HUD_MAX_X-12, 152, alt, 1, FONT_STD, status.colors.hudSideText, RIGHT)
    end
  end

  -- telemetry.hSpeed and telemetry.airspeed are in dm/s
  local hSpeed = libs.utils.getMaxValue(status.telemetry.hSpeed,MAX_HSPEED) * 0.1 * status.conf.horSpeedMultiplier
  local speed = hSpeed

  if status.airspeedEnabled == 1 then
    speed = status.telemetry.airspeed * 0.1 * status.conf.horSpeedMultiplier
    lcd.color(status.colors.black)
    lcd.pen(SOLID)
    lcd.drawFilledRectangle(HUD_MIN_X, 156, 80, 18)
    libs.drawLib.drawText(HUD_MIN_X+78, 159, "G", FONT_S, status.colors.hudSideText,RIGHT)
  end

  if (math.abs(speed) >= 10) then
    libs.drawLib.drawNumber(HUD_MIN_X+2, 114, speed, 0, FONT_XXL, status.colors.hudSideText)
    if status.airspeedEnabled == 1 then
      libs.drawLib.drawNumber(HUD_MIN_X+2, 152, hSpeed, 0, FONT_STD, status.colors.hudSideText)
    end
  else
    libs.drawLib.drawNumber(HUD_MIN_X+2, 114, speed, 1, FONT_XXL, status.colors.hudSideText)
    if status.airspeedEnabled == 1 then
      libs.drawLib.drawNumber(HUD_MIN_X+2, 152, hSpeed, 1, FONT_STD, status.colors.hudSideText)
    end
  end
  --]]

  -- wind
  if status.conf.enableWIND == true then
    lcd.color(status.colors.black)
    lcd.pen(SOLID)
    lcd.drawFilledRectangle(HUD_MIN_X, 180, 80, 19)
    libs.drawLib.drawText(HUD_MIN_X + 80,184,"W",FONT_S,status.colors.white,RIGHT)
    libs.drawLib.drawNumber(HUD_MIN_X+2,178,status.telemetry.trueWindSpeed*status.conf.horSpeedMultiplier*0.1,1,FONT_STD,status.colors.white)
  end
  --[[
  lcd.color(CUSTOM_COLOR,COLOR_TEXT)
  -- min/max arrows
  if status.showMinMaxValues == true then
    drawLib.drawVArrow(168, 73,true,false,utils)
    drawLib.drawVArrow(301, 73,true,false,utils)
  end
  --]]
  -- vspeed box
  local vSpeed = libs.utils.getMaxValue(status.telemetry.vSpeed,MAX_VSPEED) * 0.1 -- m/s

  if math.abs(vSpeed*status.conf.vertSpeedMultiplier*10) > 99 then --
    libs.drawLib.drawNumber(386, 203, vSpeed*status.conf.vertSpeedMultiplier, 0, FONT_XL, status.colors.white, CENTERED)
  else
    libs.drawLib.drawNumber(386, 203, vSpeed*status.conf.vertSpeedMultiplier, 1, FONT_XL, status.colors.white, CENTERED)
  end
  --]]
  -- pitch and roll
  libs.drawLib.drawNumber(386,142,status.telemetry.pitch,0,FONT_STD,status.colors.white, CENTERED)
  libs.drawLib.drawNumber(360,124,status.telemetry.roll,0,FONT_STD,status.colors.white, RIGHT)
end

function hudLib.init(param_status, param_libs)
  status = param_status
  libs = param_libs
  return hudLib
end

return hudLib
