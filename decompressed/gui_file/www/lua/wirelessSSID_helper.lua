local ipairs, string = ipairs, string
local format = string.format
local proxy = require("datamodel")
local content_helper = require("web.content_helper")
local frequency = {}
local M = {}

local function getFrequencyBand(v)
  if not v or v == "" then return "" end
  if frequency[v] then
    return frequency[v]
  end
  local path = format("rpc.wireless.radio.@%s.supported_frequency_bands", v)
  local res = proxy.get(path)
  local radio = (res and res[1] and res[1].value) or ""
  frequency[v] = radio
  return radio
end

function M.getSSID()
  local ssid_list = {}
  local raw = proxy.get("rpc.wireless.ssid.")
  if not raw then return ssid_list end
  local ssids = content_helper.convertResultToObject("rpc.wireless.ssid.", raw)
  for _, item in ipairs(ssids) do
    if item.radio and item.oper_state then
      local display_ssid = item.ap_display_name
      if not display_ssid or display_ssid == "" then
        if item.stb == "1" then
          display_ssid = "IPTV"
        else
          display_ssid = item.ssid or ""
        end
      end
      ssid_list[#ssid_list+1] = {
        radio = getFrequencyBand(item.radio),
        ssid = display_ssid,
        state = item.oper_state,
      }
    end
  end
  return ssid_list
end

return M
