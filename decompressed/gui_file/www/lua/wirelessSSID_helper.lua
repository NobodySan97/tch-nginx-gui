local ipairs, string = ipairs, string
local format = string.format
local proxy = require("datamodel")
local frequency = {}
local M = {}

local function getValue(path)
  local result = proxy.get(path)
  return result and result[1] and result[1].value or ""
end

local function getFrequencyBand(v)
  if frequency[v] then
    return frequency[v]
  end
  -- Primary: hostapd/ubus wireless.radio (works on hostapd-based firmware)
  local path = format("rpc.wireless.radio.@%s.supported_frequency_bands", v)
  local radio = getValue(path)
  -- Fallback for Broadcom (wl) firmware where rpc.wireless.radio returns no
  -- entries: derive the band from the radio name (radio_2G -> 2.4GHz, ...).
  if radio == "" then
    if v:match("2G") or v:match("2g") then
      radio = "2.4GHz"
    elseif v:match("5G") or v:match("5g") then
      radio = "5GHz"
    elseif v:match("6G") or v:match("6g") then
      radio = "6GHz"
    end
  end
  if radio ~= "" then
    frequency[v] = radio
  end
  return radio
end

function M.getSSID()
  local ssid_list = {}
  -- Primary source: hostapd/ubus wireless.ssid (works on hostapd-based firmware)
  local pn = proxy.getPN("rpc.wireless.ssid.", true)
  if pn and #pn > 0 then
    for _, v in ipairs(pn) do
      local path = v.path
      local values = proxy.get(path .. "radio", path .. "ssid", path .. "oper_state")
      if values and values[1] and values[2] and values[3] then
        local ap_display_name = getValue(path .. "ap_display_name")
        local display_ssid
        if ap_display_name ~= "" then
          display_ssid = ap_display_name
        elseif getValue(path .. "stb") == "1" then
          display_ssid = "IPTV"
        else
          display_ssid = values[2].value
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
  -- Fallback for Broadcom (wl) firmware where rpc.wireless.ssid. returns no
  -- entries: enumerate wifi-iface sections from UCI wireless config.
  local ifaces = proxy.getPN("uci.wireless.wifi-iface.", true)
  if not ifaces or #ifaces == 0 then
    return ssid_list
  end
  for _, v in ipairs(ifaces) do
    local path = v.path
    local dev = getValue(path .. "device")
    local ssid = getValue(path .. "ssid")
    local state = getValue(path .. "state")
    local mode = getValue(path .. "mode")
    if mode == "" then mode = "ap" end
    if mode == "ap" and ssid ~= "" then
      local display_ssid = ssid
      if getValue(path .. "stb") == "1" then
        display_ssid = "IPTV"
      end
      local ap_display_name = getValue(path .. "ap_display_name")
      if ap_display_name ~= "" then
        display_ssid = ap_display_name
      end
      ssid_list[#ssid_list+1] = {
        radio = getFrequencyBand(dev),
        ssid = display_ssid,
        state = (state == "1" or state == "up") and "1" or "0",
      }
    end
  end
  return ssid_list
end

return M