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


local panel = {}

local status = nil
local libs = nil

local function drawBarSensor(x,y,label,value,unit,font,label_font,unit_font,color,label_color,blink,flags)
  lcd.font(label_font)
  local lw,lh = lcd.getTextSize(label)
  local sw,sh = lcd.getTextSize(" ")
  lcd.font(unit_font)
  local uw,uh = lcd.getTextSize(unit)
  lcd.font(font)
  local vw,vh = lcd.getTextSize(value)

  if flags == RIGHT then
    libs.drawLib.drawText(x, y+vh-uh, unit, unit_font, color, RIGHT, blink)
    libs.drawLib.drawText(x-uw, y, value, font, color,RIGHT,blink)
    libs.drawLib.drawText(x-(uw+sw+vw), y+vh-lh, label, label_font, label_color,RIGHT,blink)
  else
    libs.drawLib.drawText(x, y+vh-lh, label, label_font, label_color,LEFT,blink)
    libs.drawLib.drawText(x+lw+sw, y, value, font, color,LEFT,blink)
    libs.drawLib.drawText(x+lw+sw+vw, y+vh-uh, unit, unit_font, color,LEFT,blink)
  end
  return lw + vw + uw + 3*sw
end

function panel.draw(widget)
  libs.mapLib.drawMap(widget, 0, 22, 480, 272-(22+22), status.mapZoomLevel, 5, 3, status.telemetry.cog)

  lcd.color(lcd.RGB(0,0,0))
  lcd.pen(SOLID)
  lcd.drawFilledRectangle(0, 0, 480, 22)
  lcd.drawFilledRectangle(0, 272-22, 480, 22)

  libs.drawLib.drawTopBar()

  -- overlays
  lcd.font(FONT_STD)
  lcd.pen(SOLID)
  -- GPS coordinates
  lcd.color(lcd.RGB(0, 0, 0, 0.25))
  local w,h = lcd.getTextSize(status.telemetry.strLat.."  "..status.telemetry.strLon)
  lcd.drawFilledRectangle(480-w-5, 22+2, w, h)
  lcd.color(status.colors.white)
  lcd.drawText(480-w+5, 22+2, status.telemetry.strLat.."  "..status.telemetry.strLon)
  -- Zoom level
  w,h = lcd.getTextSize("zoom "..tostring(status.mapZoomLevel))
  lcd.color(lcd.RGB(0, 0, 0, 0.25))
  lcd.drawFilledRectangle(5, 22+2, w, h)
  lcd.color(status.colors.white)
  lcd.drawText(5, 22+2, "zoom "..tostring(status.mapZoomLevel))

  -- bottom bar
  local labelColor = lcd.RGB(170,170,170)
  local offset = drawBarSensor(0,272-22,"GSpd",string.format("%.01f", status.avgSpeed.value * status.conf.horSpeedMultiplier), status.conf.horSpeedLabel, FONT_L, FONT_S, FONT_S, status.colors.white, labelColor, false)
  offset = offset + drawBarSensor(offset,272-22,"Hdg",string.format("%.0f", status.telemetry.cog == nil and 0 or status.telemetry.cog), "°", FONT_L, FONT_S, FONT_STD, status.colors.white, labelColor, false)

  if status.telemetry.lat ~= nil then
    if status.telemetry.homeLat == nil or status.telemetry.homeLon == nil then
      lcd.color(status.colors.yellow)
      libs.drawLib.drawText(480, 272-22+2, "WARNING:  HOME  NOT  SET!", FONT_L, status.colors.yellow, RIGHT, true)
      --lcd.drawText(480, 272-22+2, "WARNING: HOME NOT SET!", RIGHT)
    else
      -- home directory arrow
      libs.drawLib.drawRArrow(480 - 1.3*29, 272-2.1*29, 24, math.floor(status.telemetry.homeAngle - (status.telemetry.yaw == nil and (status.telemetry.cog == nil and 0 or status.telemetry.cog) or status.telemetry.yaw)),status.colors.yellow)
      libs.drawLib.drawRArrow(480 - 1.3*29, 272-2.1*29, 29, math.floor(status.telemetry.homeAngle - (status.telemetry.yaw == nil and (status.telemetry.cog == nil and 0 or status.telemetry.cog) or status.telemetry.yaw)),status.colors.black)

      lcd.font(FONT_L)
      lcd.color(status.colors.white)
      --lcd.drawText(480, 272-22+2, string.format("travel %.1f%s  home %.0f%s",status.avgSpeed.travelDist*status.conf.distUnitLongScale,status.conf.distUnitLongLabel,status.telemetry.homeDist * status.conf.distUnitScale, status.conf.distUnitLabel), RIGHT)
      offset = drawBarSensor(480,272-22,"Travel",string.format("%.01f", status.avgSpeed.travelDist*status.conf.distUnitLongScale), status.conf.distUnitLongLabel, FONT_L, FONT_S, FONT_S, status.colors.white, labelColor, false, RIGHT)
      drawBarSensor(480-offset,272-22,"HomeDist",string.format("%.01f", status.telemetry.homeDist * status.conf.distUnitScale), status.conf.distUnitLabel, FONT_L, FONT_S, FONT_S, status.colors.white, labelColor, false, RIGHT)
    end
  end
end

function panel.background(widget)
end

function panel.init(param_status, param_libs)
  status = param_status
  libs = param_libs
  return panel
end

return panel
