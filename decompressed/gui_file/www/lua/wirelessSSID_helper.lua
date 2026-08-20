local ipairs, string = ipairs, string
local format = string.format
local proxy = require("datamodel")
local frequency = {}
local M = {}

local function getFrequencyBand(v)
  if not v or v == "" then return "" end
  if frequency[v] then
    return frequency[v]
  end
  local path = format("rpc.wireless.radio.@%s.supported_frequency_bands",v)
  local res = proxy.get(path)
  local radio = res and res[1] and res[1].value or ""
  frequency[v] = radio
  return radio
end

function M.getSSID()
  local ssid_list = {}
  local pns = proxy.getPN("rpc.wireless.ssid.", true)
  for _, v in ipairs(pns or {}) do
    local path = v.path
    local values = proxy.get(path .. "radio" , path .. "ssid", path .. "oper_state")
    if values and values[1] and values[2] and values[3] then
      local ap_res = proxy.get(path .. "ap_display_name")
      local ap_display_name = ap_res and ap_res[1] and ap_res[1].value or ""
      local display_ssid
      if ap_display_name ~= "" then
        display_ssid = ap_display_name
      else
        local stb_res = proxy.get(path .. "stb")
        if stb_res and stb_res[1] and stb_res[1].value == "1" then
          display_ssid = "IPTV"
        else
          display_ssid = values[2].value
        end
      end
      ssid_list[#ssid_list+1] = {
        radio = getFrequencyBand(values[1].value),
        ssid = display_ssid,
        state = values[3].value,
      }
    end
  end
  return ssid_list
end

return M
