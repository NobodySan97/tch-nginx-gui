-- Enable localization
gettext.textdomain('webui-mobiled')

local json = require("dkjson")
local ngx = ngx
local tonumber, tostring = tonumber, tostring
local format = string.format

local old_rx_value = "1000"
local old_tx_value = "1000"
local interface = "ptm0"

local args = ngx.req.get_uri_args()
if args then
  old_rx_value = args.oldrx or "1000"
  old_tx_value = args.oldtx or "1000"
  if args.interface and tostring(args.interface):match("^[a-zA-Z0-9_%.%-]+$") then
    interface = tostring(args.interface)
  end
end

local function read_net_stat(intf, stat)
  local path = format("/sys/class/net/%s/statistics/%s", intf, stat)
  local f = io.open(path, "r")
  if f then
    local val = f:read("*l") or f:read("*a")
    f:close()
    if val then
      return val:gsub("%s+", "")
    end
  end
  return "0"
end

local rx_traffic = read_net_stat(interface, "rx_bytes")
local tx_traffic = read_net_stat(interface, "tx_bytes")

local data = {
	old_rx_traffic = old_rx_value,
	old_tx_traffic = old_tx_value,
	rx_traffic = rx_traffic,
	tx_traffic = tx_traffic
}

local buffer = {}
if json.encode(data, { indent = false, buffer = buffer }) then
	ngx.say(buffer)
else
	ngx.say("{}")
end
ngx.exit(ngx.HTTP_OK)