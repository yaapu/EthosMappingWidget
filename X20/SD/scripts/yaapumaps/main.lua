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


local mapStatus = {
  -- telemetry
  telemetry = {
    yaw = nil,
    roll = nil,
    pitch = nil,
    -- GPS
    lat = nil,
    lon = nil,
    strLat = "---",
    strLon = "---",
    groundSpeed = 0,
    cog = 0,
    -- HOME
    homeLat = nil,
    homeLon = nil,
    homeAngle = 0,
    homeDist = 0,
    -- RSSI
    rssi = 0,
    rssiCRSF = 0,
  },

  -- configuration
  conf = {
    -- unit setup
    horSpeedUnit = 1,
    horSpeedMultiplier=1,
    horSpeedLabel = "m/s",
    vertSpeedUnit = 1,
    vertSpeedMultiplier=1,
    vertSpeedLabel = "m/s",
    distUnit = 1,
    distUnitLabel = "m",
    distUnitScale = 1,
    distUnitLong = 1,
    distUnitLongLabel = "km",
    distUnitLongScale = 0.001,
    language = "en",
    -- map support
    mapProvider = 2, -- 1 GMapCatcher, 2 Google
    mapType = "GoogleSatelliteMap", -- applies to gmapcacther only
    mapZoomLevel = 19,
    mapZoomMax = 20,
    mapZoomMin = 1,
    mapTrailDots = 30,
    enableMapGrid = true,
    screenToggleChannelId = 0,
    screenWheelChannelId = 0,
    screenWheelChannelDelay = 20,
    gpsFormat = 0, -- decimal
    -- layout
    layout = 1,
  },

  -- panels
  layoutFilenames = {
    "layout_default",
  },
  counter = 0,

  -- layout
  lastScreen = 1, -- allows to switch to a different screen on same widget
  loadCycle = 0,
  layout = { nil },

  -- telemetry status
  noTelemetryData = 1,
  hideNoTelemetry = false,

  -- maps
  screenTogglePage = 1,
  mapZoomLevel = 19,
  lastLat = nil,
  lastLon = nil,
  avgSpeed = {
    lastSampleTime = nil,
    avgTravelDist = 0,
    avgTravelTime = 0,
    travelDist = 0,
    prevLat = nil,
    prevLon = nil,
    value = 0,
  },

  -- top bar
  linkQualitySource = nil,
  userSensor1 = nil,
  userSensor2 = nil,
  userSensor3 = nil,

  -- blinking suppport
  blinkon = false,

  -- UNIT CONVERSION
  unitConversion = {},
  battPercByVoltage = {},
  colors = {
    white = WHITE,
    red = RED,
    green = GREEN,
    black = BLACK,
    yellow = lcd.RGB(255,206,0),
    panelLabel = lcd.RGB(150,150,150),
    panelText = lcd.RGB(255,255,255),
    panelBackground = lcd.RGB(56,60,56),
    barBackground = BLACK,
    barText = WHITE,
    hudSky = lcd.RGB(123,157,255),
    hudTerrain = lcd.RGB(100,185,95),
    hudDashes = lcd.RGB(250, 205, 205),
    hudLines = lcd.RGB(220, 220, 220),
    hudSideText = lcd.RGB(0,238,49),
    hudText = lcd.RGB(255,255,255),
    rpmBar = lcd.RGB(240,192,0),
    background = lcd.RGB(60, 60, 60)
  },
}

--[[
UNIT_AMPERE
UNIT_AMPERE_HOUR
UNIT_CELSIUS
UNIT_CENTIMETER
UNIT_CENTIMETER_PER_SECOND
UNIT_DB
UNIT_DBM
UNIT_DEGREE
UNIT_FAHRENHEIT
UNIT_FOOT
UNIT_FOOT_PER_SECOND
UNIT_G
UNIT_HERTZ
UNIT_HOUR
UNIT_KILOMETER
UNIT_KNOT
UNIT_KPH
UNIT_METER
UNIT_METER_PER_SECOND
UNIT_MICROSECOND
UNIT_MILLIAMPERE
UNIT_MILLIAMPERE_HOUR
UNIT_MILLILITER
UNIT_MILLILITER_PER_MINUTE
UNIT_MILLILITER_PER_PULSE
UNIT_MILLISECOND
UNIT_MILLIVOLT
UNIT_MILLIWATT
UNIT_MINUTE
UNIT_MPH
UNIT_PERCENT
UNIT_RADIAN
UNIT_RPM
UNIT_SECOND
UNIT_VOLT
UNIT_WATT
]]

-- { value, decimals, unit}
mapStatus.luaSourcesConfig = {}

mapStatus.luaSourcesConfig.HomeDistance =  {0, 0, UNIT_METER, "homeDist", 1}
mapStatus.luaSourcesConfig.CourseOverGround =  {0, 0, UNIT_DEGREE, "cog", 1}
mapStatus.luaSourcesConfig.GroundSpeed =  {0, 1, UNIT_METER_PER_SECOND, "groundSpeed", 1}

local function sourceWakeup(source)
  if source ~= nil then
    local v = mapStatus.luaSourcesConfig[source:name()]
    if v[2] == 0 then
      source:value(tonumber(mapStatus.telemetry[v[4]])==nil and 0 or math.floor(0.5 + mapStatus.telemetry[v[4]] * v[5]))
    else
      source:value(tonumber(mapStatus.telemetry[v[4]])==nil and 0 or (mapStatus.telemetry[v[4]] * v[5]))
    end
  end
end

local mapLibs = {
  drawLib = nil,
  hudLib = nil,
  resetLib = nil,
  mapsLib = nil,
  utils = nil,
}

function loadLib(name)
  local lib = dofile("/scripts/yaapumaps/lib/"..name..".lua")
  if lib.init ~= nil then
    lib.init(mapStatus, mapLibs)
  end
  return lib
end

local function initLibs()
  if mapLibs.utils == nil then
    mapLibs.utils = loadLib("utils")
  end
  if mapLibs.drawLib == nil then
    mapLibs.drawLib = loadLib("drawlib")
  end
  if mapLibs.hudLib == nil then
    mapLibs.hudLib = loadLib("hudlib")
  end
  if mapLibs.resetLib == nil then
    mapLibs.resetLib = loadLib("resetlib")
  end
  if mapLibs.mapLib == nil then
    mapLibs.mapLib = loadLib("maplib")
  end
end

local function checkSize(widget)
  w, h = lcd.getWindowSize()
  text_w, text_h = lcd.getTextSize("")
  lcd.font(FONT_STD)
  lcd.drawText(w/2, (h - text_h)/2, w.." x "..h, CENTERED)
  return true
end

local function createOnce(widget)
  -- only this widget instance will run bg tasks
  widget.runBgTasks = true
end

local function reset(widget)
  mapLibs.resetLib.reset(widget)
end


local function loadLayout(widget)

  lcd.pen(SOLID)
  lcd.color(lcd.RGB(20, 20, 20))
  lcd.drawFilledRectangle(198, 98, 400, 140)
  lcd.color(mapStatus.colors.white)
  lcd.drawRectangle(198, 98, 400, 140,3)
  lcd.color(mapStatus.colors.white)
  lcd.font(FONT_XXL)
  lcd.drawText(400, 145, "loading layout...", CENTERED)

  if mapStatus.layout[widget.screen] == nil then
    mapStatus.layout[widget.screen] = loadLib(mapStatus.layoutFilenames[widget.screen])
  end
  widget.ready = true
end

mapStatus.blinkTimer = getTime()
local bgclock = 0

local function bgtasks(widget)
  -- blinking support
  local now = getTime()
  mapStatus.counter = mapStatus.counter + 1

  -- update gps telemetry data
  local gpsData = {}
  gpsData.lat = system.getSource({name="GPS", options=OPTION_LATITUDE}):value()
  gpsData.lon = system.getSource({name="GPS", options=OPTION_LONGITUDE}):value()
  if gpsData.lat ~= nil and gpsData.lon ~= nil then
    mapStatus.telemetry.lat = gpsData.lat
    mapStatus.telemetry.lon = gpsData.lon
  end
  if mapStatus.telemetry.lat ~= nil and mapStatus.telemetry.lon ~= nil then
    -- PROCESS GPS DATA
    if mapStatus.avgSpeed.lastLat == nil or mapStatus.avgSpeed.lastLon == nil then
      mapStatus.avgSpeed.lastLat = mapStatus.telemetry.lat
      mapStatus.avgSpeed.lastLon = mapStatus.telemetry.lon
      mapStatus.avgSpeed.lastSampleTime = now
    end

    if now - mapStatus.avgSpeed.lastSampleTime > 100 then
      local travelDist = mapLibs.utils.haversine(mapStatus.telemetry.lat, mapStatus.telemetry.lon, mapStatus.avgSpeed.lastLat, mapStatus.avgSpeed.lastLon)
      local travelTime = now - mapStatus.avgSpeed.lastSampleTime
      local speed = travelDist/travelTime
      -- discard sampling errors
      if travelDist < 10000 then
        -- 5 point moving average, about 10 seconds data
        mapStatus.avgSpeed.avgTravelDist = mapStatus.avgSpeed.avgTravelDist * 0.8 + travelDist*0.2
        mapStatus.avgSpeed.avgTravelTime = mapStatus.avgSpeed.avgTravelTime * 0.8 + 0.01 * travelTime * 0.2
        mapStatus.avgSpeed.value = mapStatus.avgSpeed.avgTravelDist/mapStatus.avgSpeed.avgTravelTime
        mapStatus.avgSpeed.travelDist = mapStatus.avgSpeed.travelDist + mapStatus.avgSpeed.avgTravelDist
        mapStatus.telemetry.groundSpeed = mapStatus.avgSpeed.value
      end
      mapStatus.avgSpeed.lastLat = mapStatus.telemetry.lat
      mapStatus.avgSpeed.lastLon = mapStatus.telemetry.lon
      mapStatus.avgSpeed.lastSampleTime = now
      -- home distance
      if mapStatus.telemetry.homeLat ~= nil and mapStatus.telemetry.homeLon ~= nil then
        mapStatus.telemetry.homeDist = mapLibs.utils.haversine(mapStatus.telemetry.lat, mapStatus.telemetry.lon, mapStatus.telemetry.homeLat, mapStatus.telemetry.homeLon)
        mapStatus.telemetry.homeAngle = mapLibs.utils.getAngleFromLatLon(mapStatus.telemetry.lat, mapStatus.telemetry.lon, mapStatus.telemetry.homeLat, mapStatus.telemetry.homeLon)
      end
    end
  end

  -- SLOWER
  if bgclock % 4 == 2 then
    if mapStatus.telemetry.lat ~= nil and mapStatus.telemetry.lon ~= nil then
      if mapStatus.conf.gpsFormat == 1 then
        -- DMS
        mapStatus.telemetry.strLat = mapLibs.utils.decToDMSFull(mapStatus.telemetry.lat)
        mapStatus.telemetry.strLon = mapLibs.utils.decToDMSFull(mapStatus.telemetry.lon, mapStatus.telemetry.lat)
      else
        -- decimal
        mapStatus.telemetry.strLat = string.format("%.06f", mapStatus.telemetry.lat)
        mapStatus.telemetry.strLon = string.format("%.06f", mapStatus.telemetry.lon)
      end
    end
    mapLibs.utils.updateCog()
  end
  if now - mapStatus.blinkTimer > 60 then
    mapStatus.blinkon = not mapStatus.blinkon
    mapStatus.blinkTimer = now
  end
  bgclock = (bgclock%4)+1
end

local function onScreenChange(widget)
end

local function wrap360(angle)
    local res = angle % 360
    if res < 0 then
        res = res + 360
    end
    return res
end

local bitmaskCache = {}

local fg_counter = 0
local fg_rate = 0
local fg_timer = 0

local function gpsDataAvailable(lat,lon)
  return lat ~= nil and lon ~= nil and lat ~= 0 and lon ~= 0
end

-- called only when visible
local function paint(widget)
  lcd.color(mapStatus.colors.background)
  lcd.pen(SOLID)
  lcd.drawFilledRectangle(0,0,800,480)

  local now = getTime()
  if mapStatus.lastScreen ~= widget.screen then
    onScreenChange(widget)
    mapStatus.lastScreen = widget.screen
  end

  if not checkSize(widget) then
    return
  end

  if not widget.ready then
      loadLayout(widget);
  else
    mapStatus.layout[widget.screen].draw(widget)
  end
  -- skip first iteration
  if fg_rate == 0 then
    fg_rate = fg_counter
  end

  fg_counter=fg_counter+1

  if now - fg_timer > 100 then
    fg_rate = fg_rate*0.5 + fg_counter*0.5
    fg_counter = 0
    fg_timer = now
  end


  if not gpsDataAvailable(mapStatus.telemetry.lat, mapStatus.telemetry.lon) then
    mapLibs.drawLib.drawNoGPSData(widget)
  end

  lcd.font(FONT_S)
  lcd.color(mapStatus.colors.yellow)
end

-- called when event is passed to the widget
-- called when event is passed to the widget
local function event(widget, category, value, x, y)
  local kill = false
  if category == EVT_TOUCH and value == 16641 then
    kill = true
    if mapLibs.drawLib.isInside(x, y, 800*0.625, 0,800, 480/2) == true then
      mapStatus.mapZoomLevel = math.min(mapStatus.conf.mapZoomMax, mapStatus.mapZoomLevel+1)
    elseif mapLibs.drawLib.isInside(x, y, 800*0.625, 480/2, 800,480) == true then
      mapStatus.mapZoomLevel = math.max(mapStatus.conf.mapZoomMin, mapStatus.mapZoomLevel-1)
    else
      kill = false
    end
  end
  if kill then
    system.killEvents(value)
    return true
  end
  return false
end

local function setHome(widget)
  mapStatus.telemetry.homeLat = mapStatus.telemetry.lat
  mapStatus.telemetry.homeLon = mapStatus.telemetry.lon
end

-- widget custom context menu
local function menu(widget)
  if mapStatus.telemetry.lat ~= nil and mapStatus.telemetry.lon ~= nil then
    return {
      { "Maps: Reset",function() reset(widget) end },
      { "Maps: Set Home",function() setHome(widget) end },
      { "Maps: Zoom in", function() mapStatus.mapZoomLevel = math.min(mapStatus.conf.mapZoomMax, mapStatus.mapZoomLevel+1) end},
      { "Maps: Zoom out", function() mapStatus.mapZoomLevel = math.max(mapStatus.conf.mapZoomMin, mapStatus.mapZoomLevel-1) end},
    }
  end
    return {
      { "Maps: Reset",function() reset(widget) end }
    }
end


local function wakeup(widget)
  local now = getTime()
  -- one time init
  -- multiple instances of the same
  -- widget need to call this only once
  if mapStatus.initPending then
    createOnce(widget)
    mapStatus.initPending = false
  end

  if widget.runBgTasks then
    bgtasks(widget)
  end
  lcd.invalidate()
end

------------------------------------------------
-- create() is called once at widget creation
-- it sets widget properties
-- mapStatus.conf is shared between widget instances
-------------------------------------------------
local function create()
    if not mapStatus.initPending then
      mapStatus.initPending = true
    end

    initLibs()

    return {
      ------------------
      -- shared config
      ------------------
      conf = mapStatus.conf,

      ------------------
      -- widget config
      ------------------
      ready = false,
      runBgTasks = false,
      -- screen type
      screen=1,
      -- panel config
      centerPanelIndex = 1,
      leftPanelIndex = 1,
      rightPanelIndex = 1,
      -------------------
      -- widget properties
      -------------------
      layout = nil,
      centerPanel = nil,
      leftPanel = nil,
      rightPanel = nil,
      name = "yaapumaps",
    }
end

local function applyDefault(value, defaultValue, lookup)
  local v = value ~= nil and value or defaultValue
  if lookup ~= nil then
    return lookup[v]
  end
  return v
end

local function storageToConfig(name, defaultValue, lookup)
  local storageValue = storage.read(name)
  local value = applyDefault(storageValue, defaultValue, lookup)
  return value
end

local function configToStorage(value, lookup)
  if lookup ~= nil then
    for i=1,#lookup
    do
      if lookup[i] == value then
        return i
      end
    end
    return 1 -- assume 1 as default index
  end
  return value
end

local function applyConfig()

  mapStatus.conf.horSpeedLabel = applyDefault(mapStatus.conf.horSpeedUnit, 1, {"m/s", "km/h", "mph", "kn"})
  mapStatus.conf.vertSpeedLabel = applyDefault(mapStatus.conf.vertSpeedUnit, 1, {"m/s", "ft/s", "ft/min"})
  mapStatus.conf.distUnitLabel = applyDefault(mapStatus.conf.distUnit, 1, {"m", "ft"})
  mapStatus.conf.distUnitLongLabel = applyDefault(mapStatus.conf.distUnitLong, 1, {"km", "mi"})

  mapStatus.conf.horSpeedMultiplier = applyDefault(mapStatus.conf.horSpeedUnit, 1, {1, 3.6, 2.23694, 1.94384})
  mapStatus.conf.vertSpeedMultiplier = applyDefault(mapStatus.conf.vertSpeedUnit, 1, {1, 3.28084, 196.85})
  mapStatus.conf.distUnitScale = applyDefault(mapStatus.conf.distUnit, 1, {1, 3.28084})
  mapStatus.conf.distUnitLongScale = applyDefault(mapStatus.conf.distUnitLong, 1, {1/1000,  1/1609.34})

  mapStatus.conf.mapType = applyDefault(mapStatus.conf.mapTypeId, 1, mapStatus.conf.mapProvider == 1 and {"sat_tiles","tiles","tiles","ter_tiles"} or {"GoogleSatelliteMap","GoogleHybridMap","GoogleMap","GoogleTerrainMap"})

  if mapStatus.conf.mapProvider == 1 then
    mapStatus.mapZoomLevel = mapStatus.conf.gmapZoomDefault
    mapStatus.conf.mapZoomMin = mapStatus.conf.gmapZoomMin
    mapStatus.conf.mapZoomMax = mapStatus.conf.gmapZoomMax
  else
    mapStatus.mapZoomLevel = mapStatus.conf.googleZoomDefault
    mapStatus.conf.mapZoomMin = mapStatus.conf.googleZoomMin
    mapStatus.conf.mapZoomMax = mapStatus.conf.googleZoomMax
  end

end
local function configure(widget)
  local line = form.addLine("Widget version")
  form.addStaticText(line, nil, "1.0.0 dev".." ("..'d1f1063'..")")

  line = form.addLine("Link quality source")
  form.addSourceField(line, nil, function() return mapStatus.conf.linkQualitySource end, function(value) mapStatus.conf.linkQualitySource = value end)

  line = form.addLine("User sensor 1")
  form.addSourceField(line, nil, function() return mapStatus.conf.userSensor1 end, function(value) mapStatus.conf.userSensor1 = value end)

  line = form.addLine("User sensor 2")
  form.addSourceField(line, nil, function() return mapStatus.conf.userSensor2 end, function(value) mapStatus.conf.userSensor2 = value end)

  line = form.addLine("User sensor 3")
  form.addSourceField(line, nil, function() return mapStatus.conf.userSensor3 end, function(value) mapStatus.conf.userSensor3 = value end)

  line = form.addLine("GPS Source")
  widget.gpsField = form.addSourceField(line, nil, function() return widget.gpsSource end, function(value) widget.gpsSource = value end );

  line = form.addLine("Airspeed/Groundspeed unit")
  form.addChoiceField(line, form.getFieldSlots(line)[0], {{"m/s", 1}, {"km/h", 2}, {"mph", 3}, {"kn",4}}, function() return mapStatus.conf.horSpeedUnit end, function(value) mapStatus.conf.horSpeedUnit = value end)

  line = form.addLine("Vertical speed unit")
  form.addChoiceField(line, form.getFieldSlots(line)[0], {{"m/s", 1}, {"ft/s", 2}, {"ft/min", 3}}, function() return mapStatus.conf.vertSpeedUnit end, function(value) mapStatus.conf.vertSpeedUnit = value end)

  line = form.addLine("Altitude/Distance unit")
  form.addChoiceField(line, form.getFieldSlots(line)[0], {{"m", 1}, {"ft", 2}}, function() return mapStatus.conf.distUnit end, function(value) mapStatus.conf.distUnit = value end)

  line = form.addLine("Long distance unit")
  form.addChoiceField(line, form.getFieldSlots(line)[0], {{"km", 1}, {"mi", 2}}, function() return mapStatus.conf.distUnitLong end, function(value) mapStatus.conf.distUnitLong = value end)

  line = form.addLine("GPS coordinates format")
  form.addChoiceField(line, form.getFieldSlots(line)[0], {{"DMS", 1}, {"Decimal", 2}}, function() return mapStatus.conf.gpsFormat end, function(value) mapStatus.conf.gpsFormat = value end)

  line = form.addLine("Map provider")
  form.addChoiceField(line, form.getFieldSlots(line)[0], {{"GMapCatcher", 1}, {"Google", 2}}, function() return mapStatus.conf.mapProvider end,
    function(value)
      mapStatus.conf.mapProvider = value
      widget.googleZoomField:enable(value==2)
      widget.googleZoomMaxField:enable(value==2)
      widget.googleZoomMinField:enable(value==2)
      widget.gmapZoomField:enable(value==1)
      widget.gmapZoomMaxField:enable(value==1)
      widget.gmapZoomMinField:enable(value==1)
    end
  )

  line = form.addLine("Map type")
  form.addChoiceField(line, form.getFieldSlots(line)[0], {{"Satellite", 1}, {"Hybrid (Google only)", 2}, {"Map", 3}, {"Terrain", 4}}, function() return mapStatus.conf.mapTypeId end, function(value) mapStatus.conf.mapTypeId = value end)

  line = form.addLine("Google zoom")
  widget.googleZoomField = form.addNumberField(line, nil, 1, 20,
    function()
      widget.googleZoomField:enable(mapStatus.conf.mapProvider==2)
      return mapStatus.conf.googleZoomDefault
    end,
    function(value)
      mapStatus.conf.googleZoomDefault = value
    end
  )

  line = form.addLine("Google zoom max")
  widget.googleZoomMaxField = form.addNumberField(line, nil, 1, 20,
    function()
      widget.googleZoomMaxField:enable(mapStatus.conf.mapProvider==2)
      return mapStatus.conf.googleZoomMax
    end,
    function(value)
      mapStatus.conf.googleZoomMax = value
      mapStatus.conf.googleZoomDefault = math.min(mapStatus.conf.googleZoomMax, mapStatus.conf.googleZoomDefault)
    end
  )

  line = form.addLine("Google zoom min")
  widget.googleZoomMinField = form.addNumberField(line, nil, 1, 20,
    function()
      widget.googleZoomMinField:enable(mapStatus.conf.mapProvider==2)
      return mapStatus.conf.googleZoomMin
    end,
    function(value)
      mapStatus.conf.googleZoomMin = value
      mapStatus.conf.googleZoomDefault = math.max(mapStatus.conf.googleZoomMin, mapStatus.conf.googleZoomDefault)
    end
  )

  line = form.addLine("GMapCatcher zoom")
  widget.gmapZoomField = form.addNumberField(line, nil, -2, 17,
    function()
      widget.gmapZoomField:enable(mapStatus.conf.mapProvider==1)
      return mapStatus.conf.gmapZoomDefault
    end,
    function(value)
      mapStatus.conf.gmapZoomDefault = value
    end
  )

  line = form.addLine("GMapCatcher zoom max")
  widget.gmapZoomMaxField = form.addNumberField(line, nil, -2, 17,
    function()
      widget.gmapZoomMaxField:enable(mapStatus.conf.mapProvider==1)
      return mapStatus.conf.gmapZoomMax
    end,
    function(value)
      mapStatus.conf.gmapZoomMax = value
      mapStatus.conf.gmapZoomDefault = math.min(mapStatus.conf.gmapZoomMax, mapStatus.conf.gmapZoomDefault)
    end
  )

  line = form.addLine("GMapCatcher zoom min")
  widget.gmapZoomMinField = form.addNumberField(line, nil, -2, 17,
    function()
      widget.gmapZoomMinField:enable(mapStatus.conf.mapProvider==1)
      return mapStatus.conf.gmapZoomMin
    end,
    function(value)
      mapStatus.conf.gmapZoomMin = value
      mapStatus.conf.gmapZoomDefault = math.max(mapStatus.conf.gmapZoomMin, mapStatus.conf.gmapZoomDefault)
    end
  )

  line = form.addLine("Enable map grid")
  form.addBooleanField(line, nil, function() return mapStatus.conf.enableMapGrid end, function(value) mapStatus.conf.enableMapGrid = value end)
end

--------------------------------------------------------------------
-- configuration read/write
-- properties must be read in the same order they are written
--------------------------------------------------------------------
local function read(widget)
  widget.gpsSource = storageToConfig("gps", nil)
  mapStatus.conf.horSpeedUnit = storageToConfig("horSpeedUnit", 1)
  mapStatus.conf.vertSpeedUnit = storageToConfig("vertSpeedUnit",1)
  mapStatus.conf.distUnit = storageToConfig("distUnit", 1)
  mapStatus.conf.distUnitLong = storageToConfig("distUnitLong", 1)
  mapStatus.conf.gpsFormat = storageToConfig("gpsFormat", 2)
  mapStatus.conf.mapProvider = storageToConfig("mapProvider", 2)
  mapStatus.conf.mapTypeId = storageToConfig("mapTypeId", 1)
  mapStatus.conf.googleZoomDefault = storageToConfig("googleZoomDefault", 18)
  mapStatus.conf.googleZoomMin = storageToConfig("googleZoomMin", 1)
  mapStatus.conf.googleZoomMax = storageToConfig("googleZoomMax", 20)
  mapStatus.conf.gmapZoomDefault = storageToConfig("gmapZoomDefault", 0)
  mapStatus.conf.gmapZoomMin = storageToConfig("gmapZoomMin", -2)
  mapStatus.conf.gmapZoomMax = storageToConfig("gmapZoomMax", 17)
  mapStatus.conf.enableMapGrid = storageToConfig("enableMapGrid", true)
  mapStatus.conf.linkQualitySource = storageToConfig("linkQualitySource", nil)
  mapStatus.conf.telemetrySource = storageToConfig("telemetrySource", nil)
  mapStatus.conf.userSensor1 = storageToConfig("userSensor1", nil)
  mapStatus.conf.userSensor2 = storageToConfig("userSensor2", nil)
  mapStatus.conf.userSensor3 = storageToConfig("userSensor3", nil)

  applyConfig()
end

local function write(widget)
  storage.write("gps", widget.gpsSource)
  storage.write("horSpeedUnit", mapStatus.conf.horSpeedUnit)
  storage.write("vertSpeedUnit", mapStatus.conf.vertSpeedUnit)
  storage.write("distUnit", mapStatus.conf.distUnit)
  storage.write("distUnitLong", mapStatus.conf.distUnitLong)
  storage.write("gpsFormat", mapStatus.conf.gpsFormat)
  storage.write("mapProvider", mapStatus.conf.mapProvider)
  storage.write("mapTypeId", mapStatus.conf.mapTypeId)
  storage.write("googleZoomDefault", mapStatus.conf.googleZoomDefault)
  storage.write("googleZoomMin", mapStatus.conf.googleZoomMin)
  storage.write("googleZoomMax", mapStatus.conf.googleZoomMax)
  storage.write("gmapZoomDefault", mapStatus.conf.gmapZoomDefault)
  storage.write("gmapZoomMin", mapStatus.conf.gmapZoomMin)
  storage.write("gmapZoomMax", mapStatus.conf.gmapZoomMax)
  storage.write("enableMapGrid", mapStatus.conf.enableMapGrid)
  storage.write("linkQualitySource", mapStatus.conf.linkQualitySource)
  storage.write("telemetrySource", mapStatus.conf.telemetrySource)
  storage.write("userSensor1", mapStatus.conf.userSensor1)
  storage.write("userSensor2", mapStatus.conf.userSensor2)
  storage.write("userSensor3", mapStatus.conf.userSensor3)

  applyConfig()
  -- reset the layout
  mapLibs.resetLib.resetLayout(widget)
end

local function sourceInit(source)
  source:value(mapStatus.luaSourcesConfig[source:name()][1])
  source:decimals(mapStatus.luaSourcesConfig[source:name()][2])
  source:unit(mapStatus.luaSourcesConfig[source:name()][3])
end

local function registerSources()
  system.registerSource({key="YM_HOME", name="HomeDistance", init=sourceInit, wakeup=sourceWakeup})
  system.registerSource({key="YM_GSPD", name="GroundSpeed", init=sourceInit, wakeup=sourceWakeup})
  system.registerSource({key="YM_COG", name="CourseOverGround", init=sourceInit, wakeup=sourceWakeup})
end

local function init()
    -- there's a limit on key size of 7 characters
    system.registerWidget({key="yaapum", name="Yaapu Mapping Widget", paint=paint, event=event, wakeup=wakeup, create=create, configure=configure, menu=menu, read=read, write=write })
    registerSources()
end

return {init=init}

