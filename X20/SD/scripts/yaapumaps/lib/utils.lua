local utils = {}

local status = nil
local libs = nil

local alwaysOn = system.getSource({category=CATEGORY_ALWAYS_ON, member=1, options=0})
local alwaysOff = system.getSource({category=0, member=1, options=0})
local sources = {}

function utils.getSourceValue(name)
  local src = sources[name]
  if src == nil then
    src = system.getSource(name)
    sources[name] = src
  end
  return src == nil and 0 or src:value()
end

function utils.getRSSI()
  return utils.getSourceValue("RSSI")
end

function utils.getBitmask(low, high)
  local key = tostring(low)..tostring(high)
  local res = bitmaskCache[key]
  if res == nil then
    res = 2^(1 + high-low)-1 << low
    bitmaskCache[key] = res
  end
  return res
end

function utils.bitExtract(value, start, len)
  return (value & utils.getBitmask(start,start+len-1)) >> start
end

function utils.processTelemetry(primID, data, now)
end

function utils.playTime(seconds)
  if seconds > 3600 then
    system.playNumber(seconds / 3600, UNIT_HOUR)
    system.playNumber((seconds % 3600) / 60, UNIT_MINUTE)
    system.playNumber((seconds % 3600) % 60, UNIT_SECOND)
  else
    system.playNumber(seconds / 60, UNIT_MINUTE)
    system.playNumber(seconds % 60, UNIT_SECOND)
  end
end

function utils.haversine(lat1, lon1, lat2, lon2)
    lat1 = lat1 * math.pi / 180
    lon1 = lon1 * math.pi / 180
    lat2 = lat2 * math.pi / 180
    lon2 = lon2 * math.pi / 180

    lat_dist = lat2-lat1
    lon_dist = lon2-lon1
    lat_hsin = math.sin(lat_dist/2)^2
    lon_hsin = math.sin(lon_dist/2)^2

    a = lat_hsin + math.cos(lat1) * math.cos(lat2) * lon_hsin
    return 2 * 6372.8 * math.asin(math.sqrt(a)) * 1000
end

function utils.getAngleFromLatLon(lat1, lon1, lat2, lon2)
  local la1 = math.rad(lat1)
  local lo1 = math.rad(lon1)
  local la2 = math.rad(lat2)
  local lo2 = math.rad(lon2)

  local y = math.sin(lo2-lo1) * math.cos(la2);
  local x = math.cos(la1)*math.sin(la2) - math.sin(la1)*math.cos(la2)*math.cos(lo2-lo1);
  local a = math.atan(y, x);

  return (a*180/math.pi + 360) % 360 -- in degrees
end

function utils.getMaxValue(value,idx)
  status.minmaxValues[idx] = math.max(value,status.minmaxValues[idx])
  return status.showMinMaxValues == true and status.minmaxValues[idx] or value
end

function utils.updateCog()
  if status.lastLat == nil then
    status.lastLat = status.telemetry.lat
  end
  if status.lastLon == nil then
    status.lastLon = status.telemetry.lon
  end
  if status.lastLat ~= nil and status.lastLon ~= nil and status.lastLat ~= status.telemetry.lat and status.lastLon ~= status.telemetry.lon then
    local cog = utils.getAngleFromLatLon(status.lastLat, status.lastLon, status.telemetry.lat, status.telemetry.lon)
    if cog ~= nil and status.telemetry.groundSpeed > 1 then
      status.telemetry.cog = cog
    end
    -- update last GPS coords
    status.lastLat = status.telemetry.lat
    status.lastLon = status.telemetry.lon
  end
end

function utils.calcMinValue(value,min)
  return min == 0 and value or math.min(value,min)
end

-- returns the actual minimun only if both are > 0
function utils.getNonZeroMin(v1,v2)
  return v1 == 0 and v2 or ( v2 == 0 and v1 or math.min(v1,v2))
end

function utils.getLatLonFromAngleAndDistance(angle, distance)
--[[
  la1,lo1 coordinates of first point
  d be distance (m),
  R as radius of Earth (m),
  Ad be the angular distance i.e d/R and
  θ be the bearing in deg

  la2 =  asin(sin la1 * cos Ad  + cos la1 * sin Ad * cos θ), and
  lo2 = lo1 + atan(sin θ * sin Ad * cos la1 , cos Ad – sin la1 * sin la2)
--]]
  if status.telemetry.lat == nil or status.telemetry.lon == nil then
    return nil,nil
  end
  local lat1 = math.rad(status.telemetry.lat)
  local lon1 = math.rad(status.telemetry.lon)
  local Ad = distance/(6371000) --meters
  local lat2 = math.asin( math.sin(lat1) * math.cos(Ad) + math.cos(lat1) * math.sin(Ad) * math.cos( math.rad(angle)) )
  local lon2 = lon1 + math.atan( math.sin( math.rad(angle) ) * math.sin(Ad) * math.cos(lat1) , math.cos(Ad) - math.sin(lat1) * math.sin(lat2))
  return math.deg(lat2), math.deg(lon2)
end

function utils.decToDMS(dec,lat)
  local D = math.floor(math.abs(dec))
  local M = (math.abs(dec) - D)*60
  local S = (math.abs((math.abs(dec) - D)*60) - M)*60
	return D .. string.format("°%04.2f", M) .. (lat and (dec >= 0 and "E" or "W") or (dec >= 0 and "N" or "S"))
end

function utils.decToDMSFull(dec,lat)
  local D = math.floor(math.abs(dec))
  local M = math.floor((math.abs(dec) - D)*60)
  local S = (math.abs((math.abs(dec) - D)*60) - M)*60
	return D .. string.format("°%d'%04.1f", M, S) .. (lat and (dec >= 0 and "E" or "W") or (dec >= 0 and "N" or "S"))
end

function utils.resetTimer()
  --print("TIMER RESET")
  local timer = model.getTimer("Yaapu")
  timer:activeCondition( alwaysOff )
  timer:resetCondition( alwaysOn )
end

function utils.startTimer()
  --print("TIMER START")
  status.lastTimerStart = getTime()/100
  local timer = model.getTimer("Yaapu")
  timer:activeCondition( alwaysOn )
  timer:resetCondition( alwaysOff )
end

function utils.stopTimer()
  --print("TIMER STOP")
  status.lastTimerStart = 0
  local timer = model.getTimer("Yaapu")
  timer:activeCondition( alwaysOff )
  timer:resetCondition( alwaysOff )
end

function utils.telemetryEnabled(widget)
  if utils.getRSSI() == 0 then
    status.noTelemetryData = 1
  end
  return status.noTelemetryData == 0
end

function utils.playSound(soundFile, skipHaptic)
  if status.conf.enableHaptic and skipHaptic == nil then
    system.playHaptic(15,0)
  end
  if status.conf.disableAllSounds then
    return
  end
  libs.drawLib.resetBacklightTimeout()
  system.playFile("/audio/yaapumaps/"..status.conf.language.."/".. soundFile..".wav")
end

function utils.init(param_status, param_libs)
  status = param_status
  libs = param_libs
  return resetLib
end

return utils
