gettext.textdomain('webui-core')

--NG-95382 [GPON-Broadband] Incorporate new GUI Pages for GPON
--NG-100650 Set 4th Ethernet Port as WAN or LAN Port on GUI
--NG-102545 GUI broadband is showing SFP Broadband GUI page when Ethernet 4 is connected
local proxy = require("datamodel")
local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")
local message_helper = require("web.uimessage_helper")
local post_helper = require("web.post_helper")
local format, match = string.format, string.match

local sfp = require("transformer.shared.sfp").readSFPFlag()

--Support ethernet mode for devices with no eth4 port
local ethname = proxy.get("sys.eth.port.@eth4.status")
if ethname and ethname[1].value then
    ethname =  "eth4"
else
    ethname =  "eth3"
end

local function get_wansensing()
	local ws = proxy.get("uci.wansensing.global.enable")
	if ws and ws[1] and ws[1].value then
		return ws[1].value
	end
	return ""
end

-- find requested interface in the uci network file, device section
local function findwan(interface)
	local pns = proxy.getPN("uci.network.device.", true)
	if pns then
		for i,v in ipairs(pns) do
			local result = match(v.path, "uci%.network%.device%.@.*".. interface .. ".*%.")
			if result then
				return (result:gsub("uci%.network%.device%.",""):gsub("%.",""))
			end
		end
	end

	return nil --return null if not found
end

local function restartNetwork()
    local ubus = require("ubus")

    local conn = ubus.connect()
    if not conn then
        return "Failed to connect to ubusd"
    end

    conn:call("network", "restart", {})

    conn:close()
end

local tablecontent = {}
tablecontent[#tablecontent + 1] = {
    name = "adsl",
    default = false,
    description = "ADSL2+",
    view = "broadband-adsl-advanced.lp",
    card = "002_broadband_xdsl.lp",
    check = function()
        if get_wansensing() == "1" then
            local L2_raw = proxy.get("uci.wansensing.global.l2type"); local L2 = L2_raw and L2_raw[1] and L2_raw[1].value or ""
            if L2 == "ADSL" then
                return true
            end
        else
            local ifname_raw = proxy.get("uci.network.interface.@wan.ifname"); local ifname = ifname_raw and ifname_raw[1] and ifname_raw[1].value or ""

            local iface = match(ifname, "atm")

            if iface then
                return true
            end
        end
    end,
    operations = function()
		local interface = findwan("atm") or "@wanatmwan"
        local difname = proxy.get("uci.network.device." .. interface .. ".ifname")
        if difname then
            local dname_raw = proxy.get("uci.network.device." .. interface .. ".name"); local dname = dname_raw and dname_raw[1] and dname_raw[1].value or ""; local difname_val = proxy.get("uci.network.device." .. interface .. ".ifname"); difname = difname_val and difname_val[1] and difname_val[1].value or ""
            if difname ~= "" and difname ~= nil then
                proxy.set("uci.network.interface.@wan.ifname", dname)
            else
                proxy.set("uci.network.interface.@wan.ifname", "atmwan")
            end
        else
            proxy.set("uci.network.interface.@wan.ifname", "atmwan")
        end
        if sfp == 1 then
            proxy.set("uci.ethernet.globals.eth4lanwanmode", "1")
        end
        if ethname == "eth3" then
            local ifnames_raw = proxy.get("uci.network.interface.@lan.ifname"); local ifnames = ifnames_raw and ifnames_raw[1] and ifnames_raw[1].value or ""
            proxy.set({
                ["uci.network.interface.@lan.ifname"] = ifnames ..' '.. ethname,
                ["uci.ethernet.port.@eth3.wan"] = "0"
            })
        end
        proxy.set("uci.wansensing.global.l2type", "ADSL")
    end,
}
tablecontent[#tablecontent + 1] = {
    name = "vdsl",
    default = true,
    description = "VDSL2",
    view = "broadband-vdsl-advanced.lp",
    card = "002_broadband_xdsl.lp",
    check = function()
        if get_wansensing() == "1" then
            local L2_raw = proxy.get("uci.wansensing.global.l2type"); local L2 = L2_raw and L2_raw[1] and L2_raw[1].value or ""
            if L2 == "VDSL" then
                return true
            end
        else
            local ifname_raw = proxy.get("uci.network.interface.@wan.ifname"); local ifname = ifname_raw and ifname_raw[1] and ifname_raw[1].value or ""

            local iface = match(ifname, "ptm0")

            if iface then
                return true
            end
        end
    end,
    operations = function()
		local interface = findwan("ptm") or "@wanptm0"
        local difname = proxy.get("uci.network.device." .. interface .. ".ifname")
        if difname then
            local dname_raw = proxy.get("uci.network.device." .. interface .. ".name"); local dname = dname_raw and dname_raw[1] and dname_raw[1].value or ""; local difname_val = proxy.get("uci.network.device." .. interface .. ".ifname"); difname = difname_val and difname_val[1] and difname_val[1].value or ""
            if difname ~= "" and difname ~= nil then
                proxy.set("uci.network.interface.@wan.ifname", dname)
            else
                proxy.set("uci.network.interface.@wan.ifname", "ptm0")
            end
        else
            proxy.set("uci.network.interface.@wan.ifname", "ptm0")
        end
        if sfp == 1 then
            proxy.set("uci.ethernet.globals.eth4lanwanmode", "1")
        end
        if ethname == "eth3" then
            local ifnames_raw = proxy.get("uci.network.interface.@lan.ifname"); local ifnames = ifnames_raw and ifnames_raw[1] and ifnames_raw[1].value or ""
            proxy.set({
                ["uci.network.interface.@lan.ifname"] = ifnames ..' '.. ethname,
                ["uci.ethernet.port.@eth3.wan"] = "0"
            })
        end
        proxy.set("uci.wansensing.global.l2type", "VDSL")
    end,
}
tablecontent[#tablecontent + 1] = {
    name = "ethernet",
    default = false,
    description = "Ethernet",
    view = "broadband-ethernet-advanced.lp",
    card = "002_broadband_ethernet.lp",
    check = function()
        if get_wansensing() == "1" then
            local L2_raw = proxy.get("uci.wansensing.global.l2type"); local L2 = L2_raw and L2_raw[1] and L2_raw[1].value or ""
            if L2 == "ETH" then
                return true
            end
        else
            local ifname_raw = proxy.get("uci.network.interface.@wan.ifname"); local ifname = ifname_raw and ifname_raw[1] and ifname_raw[1].value or ""

            local iface = match(ifname, ethname) or match(ifname, "lan") --the or is in case wan iface is br-lan
            if sfp == 1 then
                local lwmode_raw = proxy.get("uci.ethernet.globals.eth4lanwanmode"); local lwmode = lwmode_raw and lwmode_raw[1] and lwmode_raw[1].value or ""
                if iface and lwmode == "0" then
                    return true
                end
            else
                if iface then
                    return true
                end
            end
        end
    end,
    operations = function()
		local interface = findwan(ethname) or "@waneth4"
        local difname = proxy.get("uci.network.device." .. interface .. ".ifname")
        if difname then
            local dname_raw = proxy.get("uci.network.device." .. interface .. ".name"); local dname = dname_raw and dname_raw[1] and dname_raw[1].value or ""; local difname_val = proxy.get("uci.network.device." .. interface .. ".ifname"); difname = difname_val and difname_val[1] and difname_val[1].value or ""
            if difname ~= "" and difname ~= nil then
                proxy.set("uci.network.interface.@wan.ifname", dname)
            else
                proxy.set("uci.network.interface.@wan.ifname", ethname)
            end
        else
            proxy.set("uci.network.interface.@wan.ifname", ethname)
        end
        if sfp == 1 then
            proxy.set("uci.ethernet.globals.eth4lanwanmode", "0")
        end
        if ethname == "eth3" then
            local ifnames_raw = proxy.get("uci.network.interface.@lan.ifname"); local ifnames = ifnames_raw and ifnames_raw[1] and ifnames_raw[1].value or ""
            proxy.set({
                ["uci.network.interface.@lan.ifname"] = string.gsub(string.gsub(ifnames, ethname, ""), "%s$", ""),
                ["uci.ethernet.port.@eth3.wan"] = "1"
            })
        end
        proxy.set("uci.wansensing.global.l2type", "ETH")
    end,
}

if sfp == 1 then
    tablecontent[#tablecontent + 1] = {
        name = "gpon",
        default = false,
        description = "GPON",
        view = "broadband-gpon-advanced.lp",
        card = "002_broadband_gpon.lp",
        check = function()
            if get_wansensing() == "1" then
                local L2_raw = proxy.get("uci.wansensing.global.l2type"); local L2 = L2_raw and L2_raw[1] and L2_raw[1].value or ""
                local gponState = proxy.get("rpc.optical.Interface.1.Status")
                local gponState = gponState and gponState[1].value or ""
                if L2 == "SFP" or gponState == "Dormant" then
                    return true
                end
            else
                local ifname_raw = proxy.get("uci.network.interface.@wan.ifname"); local ifname = ifname_raw and ifname_raw[1] and ifname_raw[1].value or ""

                local iface = match(ifname, ethname)

                if sfp == 1 then
                    local lwmode_raw = proxy.get("uci.ethernet.globals.eth4lanwanmode"); local lwmode = lwmode_raw and lwmode_raw[1] and lwmode_raw[1].value or ""
                    if iface and lwmode == "1" then
                        return true
                    end
                else
                    if iface then
                        return true
                    end
                end
            end
        end,
        operations = function()
			local interface = findwan(ethname) or "@waneth4"
            local difname_res = proxy.get("uci.network.device." .. interface .. ".ifname")
            local difname = (difname_res and difname_res[1] and difname_res[1].value) or ""
            if difname ~= "" then
                local _dn = proxy.get("uci.network.device." .. interface .. ".name"); local dname = (_dn and _dn[1] and _dn[1].value) or interface
                proxy.set("uci.network.interface.@wan.ifname", dname)
            else
                proxy.set("uci.network.interface.@wan.ifname", ethname)
            end
            proxy.set("uci.ethernet.globals.eth4lanwanmode", "1")
            proxy.set("uci.wansensing.global.l2type", "SFP")
        end,
    }
end
return tablecontent
