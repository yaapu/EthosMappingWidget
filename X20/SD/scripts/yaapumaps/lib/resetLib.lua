local resetLib = {}
local status = nil
local libs = nil

-----------------------------
-- clears the loaded table
-- and recovers memory
-----------------------------
function resetLib.clearTable(t)
  if type(t)=="table" then
    for i,v in pairs(t) do
      if type(v) == "table" then
        resetLib.clearTable(v)
      end
      t[i] = nil
    end
  end
  t = nil
end

function resetLib.resetLayout(widget)
  -- layout
  status.loadCycle = 0
  resetLib.clearTable(status.layout)
  status.layout = { nil }
  widget.ready = false

  collectgarbage()
  collectgarbage()
end

function resetLib.reset(widget)
  resetLib.resetLayout(widget)
  collectgarbage()
  collectgarbage()
end

function resetLib.init(param_status, param_libs)
  status = param_status
  libs = param_libs
  return resetLib
end

return resetLib
