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
		
		return data
	end,
}

if action[string.untaint(data.state)] then 
	for key, val in pairs(action[string.untaint(data.state)]()) do
		data[key] = val
	end
else
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
		-- Strip curl progress bar artifacts from console display
		local clean_lines = {}
		for line in content:gmatch("[^\r\n]+") do
			local sanitized = line:gsub("^[%s#=%-O]*%d+%.?%d*%%[%s#=%-O]*", ""):gsub("^[%s#=%-O]+", ""):gsub("^%s+", "")
			if sanitized ~= "" then
				clean_lines[#clean_lines + 1] = sanitized
			end
		end
		data["log"] = table.concat(clean_lines, "\n")
	end
end

local buffer = {}
if json.encode (data, { indent = false, buffer = buffer }) then
	ngx.say(buffer)
else
	ngx.say("{}")
end

ngx.exit(ngx.HTTP_OK)
