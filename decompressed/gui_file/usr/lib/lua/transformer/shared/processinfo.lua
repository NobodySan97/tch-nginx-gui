local M = {}
local io, math = io, math
local floor = math.floor
local popen = require("modgui").popen
local open = io.open
local tostring = tostring

-- Calculates CPU usage since boot from the /proc/stat file. This value is a ratio of the non-idle time to the total usage in "USER_HZ".
-- @function M.getCPUUsage
-- @return #string, returns the CPU usage value as a percentage of the total usage.
function M.getCPUUsage()
  local user, nice, sys, idle, ioWait, irq, softIrq, steal, guest, guestNice
  local data = open("/proc/stat")
  if data then
    local firstLine = data:read("*l")
    user, nice, sys, idle, ioWait, irq, softIrq, steal, guest, guestNice = firstLine:match("^cpu%s*(%d+)%s*(%d+)%s*(%d+)%s*(%d+)%s*(%d+)%s*(%d+)%s*(%d+)%s*(%d+)%s*(%d+)%s*(%d+)")
    data:close()
  end
  if not user then
    return "0"
  end
  local cpuIdle = ioWait + idle
  local cpuNonIdle = user + nice + sys + irq + softIrq + steal + guest + guestNice
  local total = cpuIdle + cpuNonIdle
  local cpuUsage = floor(((total - cpuIdle)/total)*100)
  return tostring(cpuUsage)
end

local prev_idle, prev_total = 0, 0
-- Calculates Current cpu usage using /proc/stat deltas. Zero-fork, zero subshell overhead.
-- @function M.getCurrentCPUUsage
-- @return #string, returns the current CPU usage value.
function M.getCurrentCPUUsage()
  local data = open("/proc/stat", "r")
  if not data then return "0" end
  local firstLine = data:read("*l")
  data:close()
  if not firstLine then return "0" end
  local user, nice, sys, idle, ioWait, irq, softIrq, steal, guest, guestNice = firstLine:match("^cpu%s*(%d+)%s*(%d+)%s*(%d+)%s*(%d+)%s*(%d+)%s*(%d+)%s*(%d+)%s*(%d+)%s*(%d+)%s*(%d+)")
  if not user then return "0" end
  user = tonumber(user) or 0
  nice = tonumber(nice) or 0
  sys = tonumber(sys) or 0
  idle = tonumber(idle) or 0
  ioWait = tonumber(ioWait) or 0
  irq = tonumber(irq) or 0
  softIrq = tonumber(softIrq) or 0
  steal = tonumber(steal) or 0
  guest = tonumber(guest) or 0
  guestNice = tonumber(guestNice) or 0
  local cpuIdle = ioWait + idle
  local cpuNonIdle = user + nice + sys + irq + softIrq + steal + guest + guestNice
  local total = cpuIdle + cpuNonIdle
  if prev_total == 0 then
    prev_idle, prev_total = cpuIdle, total
    local usage = floor(((total - cpuIdle)/total)*100)
    return tostring(math.max(0, math.min(100, usage)))
  end
  local diff_idle = cpuIdle - prev_idle
  local diff_total = total - prev_total
  prev_idle, prev_total = cpuIdle, total
  if diff_total <= 0 then return "0" end
  local usage = floor(((diff_total - diff_idle)/diff_total)*100)
  return tostring(math.max(0, math.min(100, usage)))
end

return M
