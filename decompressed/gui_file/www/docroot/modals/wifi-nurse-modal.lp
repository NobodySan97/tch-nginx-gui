--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local proxy = require("datamodel")
local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local post_helper = require("web.post_helper")
local content_helper = require("web.content_helper")
local table, string = table, string
local tonumber = tonumber
local format = string.format

local ap0_raw = proxy.get("rpc.wireless.ap.@ap0.station.")
local ap1_raw = proxy.get("rpc.wireless.ap.@ap1.station.")

local ap0_stations = content_helper.convertResultToObject("rpc.wireless.ap.@ap0.station.@.", ap0_raw) or {}
local ap1_stations = content_helper.convertResultToObject("rpc.wireless.ap.@ap1.station.@.", ap1_raw) or {}

local stations_2g = {}
for _, s in ipairs(ap0_stations) do
	if s.paramindex then
		stations_2g[s.paramindex:upper()] = s
	end
end

local stations_5g = {}
for _, s in ipairs(ap1_stations) do
	if s.paramindex then
		stations_5g[s.paramindex:upper()] = s
	end
end

-- Function that gets information of a particular wireless station from the pre-fetched maps
local stationConf = {}
local getStationData = function(stationMAC)
	local mac = stationMAC and stationMAC:upper()
	local s = mac and stations_2g[mac]
	if s then
		stationConf = {
			state = s.state,
			flags = s.flags,
			capabilities = s.capabilities,
			last_rssi = s.last_rssi,
			rssi = s.rssi,
			av_rssi = s.av_rssi,
			rx_bytes = s.rx_bytes,
			tx_bytes = s.tx_bytes,
			tx_phy_rate = s.tx_phy_rate,
			rx_phy_rate = s.rx_phy_rate,
			radio = "2.4Ghz"
		}
		return true
	end
	return false
end

local getStationData5G = function(stationMAC)
	local mac = stationMAC and stationMAC:upper()
	local s = mac and stations_5g[mac]
	if s then
		stationConf = {
			state = s.state,
			flags = s.flags,
			capabilities = s.capabilities,
			last_rssi = s.last_rssi,
			rssi = s.rssi,
			av_rssi = s.av_rssi,
			rx_bytes = s.rx_bytes,
			tx_bytes = s.tx_bytes,
			tx_phy_rate = s.tx_phy_rate,
			rx_phy_rate = s.rx_phy_rate,
			radio = "5Ghz"
		}
		return true
	end
	return false
end

local hosts = proxy.get("sys.hosts.host.")
local hosts = content_helper.convertResultToObject("sys.hosts.host.",hosts)

local datarows ={}
local index = 1

--Only handle the devices that on "br-lan", others will be filtered out.
for x = 1, #hosts, 1 do
    if hosts[x].L3Interface == "br-lan" then
			local n_status
			--Here the WiFi Nurse info is populated
			if hosts[x].InterfaceType == "wireless" then
				n_status= getStationData(hosts[x].MACAddress)
				if tostring(n_status) == "true" then
					datarows[index]={}
					datarows[index][1] = hosts[x].HostName
					datarows[index][2] = stationConf["capabilities"] or ""
					local tx_rate = tonumber(stationConf["tx_phy_rate"])
					datarows[index][3] = tx_rate and (tostring(tx_rate/1000).." Mbps") or "0 Mbps"
					datarows[index][4] = "5"

					local lastRSSI = tonumber(stationConf["last_rssi"])
					if stationConf["state"] ~= "Disconnected" and lastRSSI then
						if lastRSSI > -41 then
							datarows[index][5] = T"Excellent"
							datarows[index][4] = "1"
						elseif lastRSSI > -55 then
							datarows[index][5] = T"Good"
							datarows[index][4] = "1"
						elseif lastRSSI > - 71 then
							datarows[index][5] = T"Ok"
							datarows[index][4] = "1"
						elseif lastRSSI > - 81 then
							datarows[index][5] = T"Satisfactory"
							datarows[index][4] = "3"
						else
							datarows[index][5] = T"Limited. Expect dropouts."
							datarows[index][4] = "4"
						end
					else
						datarows[index][5] = T"Disconnected"
						datarows[index][4] = "5"
					end

					datarows[index][6] = stationConf["last_rssi"] or ""
					datarows[index][7] = stationConf["av_rssi"] or ""
					datarows[index][8] = stationConf["rssi"] or ""
					local tx_b = tonumber(stationConf["tx_bytes"]) or 0
					local rx_b = tonumber(stationConf["rx_bytes"]) or 0
					datarows[index][9] = format("%.1f KB", tx_b/1000)
					datarows[index][10] = format("%.1f KB", rx_b/1000)
					datarows[index][11] = stationConf["radio"] or ""
					index = index + 1
				end

				n_status= getStationData5G(hosts[x].MACAddress)

				if tostring(n_status) == "true" then
					datarows[index]={}
					datarows[index][1] = hosts[x].HostName
					datarows[index][2] = stationConf["capabilities"] or ""
					local tx_phy = (tonumber(stationConf["tx_phy_rate"]) or 0)/1000
					datarows[index][3] = tostring(tx_phy).." ".."Mbps"
					datarows[index][4] = "5"

					local lastRSSI = tonumber(stationConf["last_rssi"]) or -100
					if stationConf["state"] ~= "Disconnected" then
						if lastRSSI > -41 then
							datarows[index][5] = T"Excellent"
							datarows[index][4] = "1"
						else
							if lastRSSI > -55 then
								datarows[index][5] = T"Good"
								datarows[index][4] = "1"
							else
								if lastRSSI > - 71 then
									datarows[index][5] = T"Ok"
									datarows[index][4] = "1"
								else
									if lastRSSI > - 81 then
										datarows[index][5] = T"Satisfactory"
										datarows[index][4] = "3"
									else
										datarows[index][5] = T"Limited. Expect dropouts."
										datarows[index][4] = "4"
									end
								end
							end
						end
					else
						datarows[index][5] = T"Disconnected"
						datarows[index][4] = "5"
					end

					datarows[index][6] = stationConf["last_rssi"] or ""
					datarows[index][7] = stationConf["av_rssi"] or ""
					datarows[index][8] = stationConf["rssi"] or ""
					local tx_b5 = (tonumber(stationConf["tx_bytes"]) or 0) / 1000
					local rx_b5 = (tonumber(stationConf["rx_bytes"]) or 0) / 1000
					datarows[index][9] = format("%.1f KB", tx_b5)
					datarows[index][10] = format("%.1f KB", rx_b5)
					datarows[index][11] = stationConf["radio"] or ""
					index = index + 1
				end
			end
    end
end

--Column Names
local columns ={}
for i=1, 11 do
    columns[i]={}
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
  ngx.print('\
\
');  ngx.print( ui_helper.createHeader(T"WiFi Nurse", false, true) ); ngx.print('\
\
<div class="modal-body update">');
	local lp = require("web.lp")
    lp.setpath("/www/snippets/")
    lp.include("tabs-device.lp")
	ngx.print('\
  <form class="form-horizontal" method="post" action="modals/wifi-nurse-modal.lp">\
    ');  
    ngx.print(ui_helper.createMessages(message_helper.popMessages()))
      ngx.print('\
\
	<legend><b>');  ngx.print( T"WiFi Nurse" ); ngx.print('</b></legend>\
	<fieldset>\
	');  
		local html = {}
		ngx.print(html)
		local options = { tableid = "networkstats", canEdit = false, editing = false, minEntries = 5, maxEntries = 7, createMsg = "Create new", canAdd = false, canDelete = false, newList = true, errmsg = nil}
		table.insert(html, ui_helper.createTable(columns, datarows, options))
		ngx.print(html)
	  ngx.print('\
	  </fieldset>\
  </form>\
</div>\
');  ngx.print( ui_helper.createFooter() ); ngx.print('\
'); 