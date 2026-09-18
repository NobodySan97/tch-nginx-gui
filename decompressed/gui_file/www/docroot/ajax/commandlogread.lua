local json = require("dkjson")
local proxy = require("datamodel")
local ngx = ngx

local data = {}

local commandstatus = proxy.get("rpc.system.modgui.executeCommand.state")
data["state"] = commandstatus and commandstatus[1] and commandstatus[1].value or "Mapper Error"

local action = { 
	Checking = function()
		local data = {}
		local new_ver = proxy.get("uci.modgui.gui.new_ver")
		if new_ver and new_ver[1] and new_ver[1].value and new_ver[1].value ~= "" then
			data["new_version_text"] = new_ver[1].value
		end
		local outdated = proxy.get("uci.modgui.gui.outdated_ver")
		if outdated and outdated[1] and outdated[1].value and outdated[1].value ~= "" then
			data["outdated_ver"] = outdated[1].value
		end
		return data
	end,
}

local untaint = string.untaint or function(s) return s end

if action[untaint(data.state)] then 
	for key, val in pairs(action[untaint(data.state)]()) do
		data[key] = val
	end

else
	if ngx.req.get_uri_args().auto_update == "true" then
		local new_ver = proxy.get("uci.modgui.gui.new_ver")
		if new_ver and new_ver[1] and new_ver[1].value and new_ver[1].value ~= "" then
			data["new_version_text"] = new_ver[1].value
		end
		local outdated = proxy.get("uci.modgui.gui.outdated_ver")
		if outdated and outdated[1] and outdated[1].value and outdated[1].value ~= "" then
			data["outdated_ver"] = outdated[1].value
		end
	end
	local file = io.open("/tmp/command_log","r")
	if file then
		local content = file:read('*a')
		file:close()
		local last_pct = nil
		for p in content:gmatch("(%d+%.?%d*)%%") do
			last_pct = p
		end
		if last_pct then
			data["progress"] = tonumber(last_pct)
		end
		-- Strip curl progress bar artifacts and ANSI escape sequences
		local clean_lines = {}
		for line in content:gmatch("[^\r\n]+") do
			local sanitized = line:gsub("\27%[[0-9;]*[a-zA-Z]", ""):gsub("\27%[[0-9;]*m", "")
			local stripped = sanitized:gsub("^[%s#=%-O]*%d+%.?%d*%%[%s#=%-O]*", ""):gsub("^[%s#=%-O]+$", ""):gsub("^%s+$", "")
			if stripped ~= "" then
				clean_lines[#clean_lines + 1] = stripped
			end
		end
		if #clean_lines == 0 and data["progress"] then
			clean_lines[1] = string.format("[Download] Download in corso... %d%%", math.floor(data["progress"]))
		end
		-- Keep only the most recent 80 lines for fast JSON serialization and UI rendering
		if #clean_lines > 80 then
			local truncated = {}
			for i = #clean_lines - 79, #clean_lines do
				truncated[#truncated + 1] = clean_lines[i]
			end
			clean_lines = truncated
		end
		data["log"] = table.concat(clean_lines, "\n")
	elseif data["state"] == "Requested" or data["state"] == "Downloading" then
		data["log"] = "[Inizializzazione] Avvio procedura in corso..."
	end
end


local buffer = {}
if json.encode (data, { indent = false, buffer = buffer }) then
	ngx.say(buffer)
else
	ngx.say("{}")
end

ngx.exit(ngx.HTTP_OK)
