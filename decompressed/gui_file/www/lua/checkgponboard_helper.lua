local lfs = require("lfs")
local M = {}
function M.isGPONBoard()
    local result = false
    local f = io.open("/proc/rip/011b", "rb")
    if f then
        local byte = f:read(1)
        f:close()
        if byte then
            local b = byte:byte()
            if b == 0x01 or b == 0x02 then
                result = true
            end
        end
    end
    return result
end

return M
