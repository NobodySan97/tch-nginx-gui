-- Enable localization
gettext.textdomain('webui-core')

local json = require("dkjson")
local ngx = ngx

local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")
local match = string.match

local devices_columns = {
  {--[2]
    header = T"Hostname",
    name = "FriendlyName",
    param = "FriendlyName",
    type = "text",
    additional_class = 'data-toggle="tooltip_mac"',
  },
  {--[3]
    header = T"IPv4",
    name = "ipv4",
    param = "IPv4",
    type = "text",
  },
  {--[6]
    header = T"InterfaceType",
    name = "interfacetype",
    param = "InterfaceType",
	type = "text",
  },
  {--[11]
    header = T"SSID",
    name = "ssid",
    param = "SSID",
    type = "text",
  },
}

--Construct the device type based on value of L2Interface
local devices_filter = function(data)

  --Display only the IP Address of physically connected devices
  if data["State"] and data["State"] == "0" then
     return false
  end

  if match(data["L2Interface"], "^wl0") then
    data["InterfaceType"] = "Wireless - 2.4GHz"
  elseif match(data["L2Interface"], "^wl1") then
    data["InterfaceType"] = "Wireless - 5GHz"
  elseif match(data["L2Interface"], "eth*") then
    data["InterfaceType"] = "Ethernet - " .. data.Port
  elseif match(data["L2Interface"], "moca*") then
    data["InterfaceType"] = "MoCA"
  end

  data["FriendlyName"] = data["FriendlyName"]..'<div id="mac_data" style="display:none">'..data["MACAddress"]..'</div>'
  
  return true
end

local devices_options = {
    canEdit = false,
    canAdd = false,
    canDelete = false,
    tableid = "devices",
    basepath = "rpc.hosts.host.",
}

local devices_data = content_helper.loadTableData(devices_options.basepath, devices_columns, devices_filter , nil)

local device_table = ui_helper.createTable(devices_columns, devices_data, devices_options, nil, nil)

local function concat_table(device_table, out) 
	for _ , table_string in pairs(device_table) do
		if type(table_string) == "table" then
			concat_table(table_string, out)
		elseif type(table_string) == "userdata" then
			out[#out+1] = string.untaint(table_string)
		else
			out[#out+1] = table_string
		end
	end
end

local device_string = {}
concat_table(device_table, device_string)

local data = {
	device_table = table.concat(device_string) or ""
}

local buffer = {}
if json.encode (data, { indent = false, buffer = buffer }) then
	ngx.say(buffer)
else
	ngx.say("{}")
end
ngx.exit(ngx.HTTP_OK)