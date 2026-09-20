--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local proxy = require("datamodel")
local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local post_helper = require("web.post_helper")
local content_helper = require("web.content_helper")
local table, string = table, string
local tonumber, tostring, ipairs = tonumber, tostring, ipairs
local format = string.format

-- Retrieve all APs and their SSIDs/Radio bands dynamically
local ap_data = content_helper.convertResultToObject("rpc.wireless.ap.", proxy.get("rpc.wireless.ap.")) or {}
local ssid_data = content_helper.convertResultToObject("rpc.wireless.ssid.", proxy.get("rpc.wireless.ssid.")) or {}
local ssid_to_radio = {}
for _, s in ipairs(ssid_data) do
	local sname = s.paramindex and (s.paramindex:match("@?([^%.]+)") or s.paramindex)
	if sname then
		ssid_to_radio[sname] = (s.radio == "radio_5G" or s.radio == "5G") and "5GHz" or "2.4GHz"
	end
end

-- Retrieve host names from sys.hosts.host.
local host_map = {}
local hosts_raw = proxy.get("sys.hosts.host.")
local hosts = content_helper.convertResultToObject("sys.hosts.host.", hosts_raw) or {}
for _, h in ipairs(hosts) do
	if h.MACAddress and h.MACAddress ~= "" then
		host_map[h.MACAddress:upper()] = h
	end
end

local datarows = {}
local index = 1

for _, ap in ipairs(ap_data) do
	local ap_name = ap.paramindex and (ap.paramindex:match("@?([^%.]+)") or ap.paramindex)
	if ap_name then
		local station_path = "rpc.wireless.ap.@" .. ap_name .. ".station."
		local stations = content_helper.convertResultToObject(station_path, proxy.get(station_path)) or {}
		local default_band = (ap.ssid and ssid_to_radio[ap.ssid]) or ((ap_name:find("1") or ap_name:find("3")) and "5GHz" or "2.4GHz")

		for _, s in ipairs(stations) do
			local mac = s.paramindex and (s.paramindex:match("@?([^%.]+)") or s.paramindex):upper()
			if mac and mac ~= "" and (s.flags ~= "" or s.state == "Connected" or (s.rssi and s.rssi ~= "0")) then
				local host_info = host_map[mac]
				local host_name = host_info and host_info.HostName and host_info.HostName ~= "" and host_info.HostName or mac
				
				local row = {}
				row[1] = host_name
				row[2] = s.capabilities or ""
				
				local tx_rate = tonumber(s.tx_phy_rate)
				row[3] = tx_rate and (format("%.1f Mbps", tx_rate / 1000)) or "0 Mbps"
				row[4] = "5"
				
				local lastRSSI = tonumber(s.last_rssi) or tonumber(s.rssi)
				if s.state ~= "Disconnected" and lastRSSI then
					if lastRSSI > -41 then
						row[5] = T"Excellent"
						row[4] = "1"
					elseif lastRSSI > -55 then
						row[5] = T"Good"
						row[4] = "1"
					elseif lastRSSI > -71 then
						row[5] = T"Ok"
						row[4] = "1"
					elseif lastRSSI > -81 then
						row[5] = T"Satisfactory"
						row[4] = "3"
					else
						row[5] = T"Limited. Expect dropouts."
						row[4] = "4"
					end
				else
					row[5] = T"Disconnected"
					row[4] = "5"
				end
				
				row[6] = s.last_rssi or ""
				row[7] = s.av_rssi or ""
				row[8] = s.rssi or ""
				
				local tx_b = tonumber(s.tx_bytes) or 0
				local rx_b = tonumber(s.rx_bytes) or 0
				row[9] = format("%.1f KB", tx_b / 1000)
				row[10] = format("%.1f KB", rx_b / 1000)
				row[11] = default_band
				
				datarows[index] = row
				index = index + 1
			end
		end
	end
end

--Column Names
local columns = {}
for i = 1, 11 do
    columns[i] = {}
end
columns[1]["header"] = T"Name"
columns[2]["header"] = T"Capabilities"
columns[3]["header"] = T"Max Speed"
columns[4]["header"] = T""
columns[4]["type"] = "light"
columns[4]["readonly"] = "true"

columns[5]["header"] = T"Signal Quality"
columns[6]["header"] = T"Last RSSI"
columns[7]["header"] = T"Avg RSSI"
columns[8]["header"] = T"RSSI"
columns[9]["header"] = T"Tx Bytes"
columns[10]["header"] = T"Rx Bytes"
columns[11]["header"] = T"Band"

ngx.print(ui_helper.createHeader(T"WiFi Nurse", false, true))
ngx.print('\n<div class="modal-body update">\n')

local lp = require("web.lp")
lp.setpath("/www/snippets/")
lp.include("tabs-device.lp")

ngx.print('\n  <form class="form-horizontal" method="post" action="modals/wifi-nurse-modal.lp">\n')
ngx.print(ui_helper.createMessages(message_helper.popMessages()))
ngx.print('\n	<legend><b>' .. T"WiFi Nurse" .. '</b></legend>\n	<fieldset>\n')

local options = { tableid = "networkstats", canEdit = false, editing = false, minEntries = 0, maxEntries = 0, canAdd = false, canDelete = false }
ngx.print(ui_helper.createTable(columns, datarows, options))

if #datarows == 0 then
	ngx.print('<div class="alert alert-info" style="margin-top: 15px; text-align: center; font-weight: 500;"><i class="icon-info-sign" style="margin-right: 6px;"></i> ' .. T"No wireless devices currently connected." .. '</div>')
end

ngx.print('\n	</fieldset>\n  </form>\n</div>\n')
ngx.print(ui_helper.createFooter())