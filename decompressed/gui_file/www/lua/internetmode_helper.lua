gettext.textdomain('webui-core')
local proxy = require("datamodel")
local gsub, match = string.gsub, string.match

local function get_real_wan_ifname()
    local ws = proxy.get("uci.wansensing.global.l2type")
    local l2 = ws and ws[1] and ws[1].value or ""
    if l2 == "VDSL" then
        return "wanptm0"
    elseif l2 == "ADSL" then
        return "wanatm0"
    elseif l2 == "ETH" or l2 == "SFP" then
        return "waneth4"
    end

    local wan_res = proxy.get("uci.network.interface.@wan.ifname")
    local curr = wan_res and wan_res[1] and wan_res[1].value or ""
    if curr ~= "" and curr ~= "br-lan" and not match(curr, "^eth[0-3]$") then
        return curr
    end

    local pns = proxy.getPN("uci.network.device.", true)
    if pns then
        for _, v in ipairs(pns) do
            local path = v.path or ""
            if match(path, "ptm") then
                local dn = proxy.get(path .. "name")
                if dn and dn[1] and dn[1].value and dn[1].value ~= "" then
                    return dn[1].value
                end
                return "wanptm0"
            elseif match(path, "eth4") then
                local dn = proxy.get(path .. "name")
                if dn and dn[1] and dn[1].value and dn[1].value ~= "" then
                    return dn[1].value
                end
            end
        end
    end

    return "wanptm0"
end

local function get_clean_lan_ifnames(wan_ifname)
    local ifnames_res = proxy.get("uci.network.interface.@lan.ifname")
    local raw = ifnames_res and ifnames_res[1] and ifnames_res[1].value or "eth0 eth1 eth2 eth3"
    local cleaned = raw
    local known_wan = {wan_ifname, "wanptm0", "waneth4", "ptm0", "eth4", "wanatm0", "atmwan"}
    for _, iface in ipairs(known_wan) do
        if iface and iface ~= "" then
            cleaned = gsub(cleaned, "%s*" .. iface .. "%s*", " ")
        end
    end
    cleaned = gsub(gsub(cleaned, "^%s+", ""), "%s+$", "")
    cleaned = gsub(cleaned, "%s+", " ")
    if cleaned == "" then cleaned = "eth0 eth1 eth2 eth3" end
    return cleaned
end

local function apply_mode(proto, mode_name)
    local wan_ifname = get_real_wan_ifname()
    local lan_clean = get_clean_lan_ifnames(wan_ifname)
    if proto == "bridge" then
        proxy.set({
            ["uci.network.interface.@wan.proto"] = "bridge",
            ["uci.network.config.wan_mode"] = "bridge",
            ["uci.network.interface.@wan.ifname"] = wan_ifname,
            ["uci.network.interface.@lan.ifname"] = lan_clean .. " " .. wan_ifname,
        })
    else
        proxy.set({
            ["uci.network.interface.@wan.proto"] = proto,
            ["uci.network.config.wan_mode"] = mode_name or proto,
            ["uci.network.interface.@wan.ifname"] = wan_ifname,
            ["uci.network.interface.@lan.ifname"] = lan_clean,
        })
    end
    return true
end

return {
    {
        name = "dhcp",
        default = true,
        description = T"DHCP routed mode",
        view = "internet-dhcp-routed.lp",
        card = "003_internet_dhcp_routed.lp",
        check = {
            { "uci.network.interface.@wan.proto", "^dhcp$"},
        },
        operations = function()
            return apply_mode("dhcp", "dhcp")
        end,
    },
    {
        name = "pppoe",
        default = false,
        description = T"PPPoE routed",
        view = "internet-pppoe-routed.lp",
        card = "003_internet_pppoe_routed.lp",
        check = {
            { "uci.network.interface.@wan.proto", "^pppoe$"},
        },
        operations = function()
            return apply_mode("pppoe", "pppoe")
        end,
    },
    {
        name = "pppoa",
        default = false,
        description = T"PPPoA routed",
        view = "internet-pppoa-routed.lp",
        card = "003_internet_pppoe_routed.lp",
        check = {
            { "uci.network.interface.@wan.proto", "^pppoa$"},
        },
        operations = function()
            return apply_mode("pppoa", "pppoa")
        end,
    },
    {
        name = "static",
        default = false,
        description = T"Fixed IP mode",
        view = "internet-static-routed.lp",
        card = "003_internet_static_routed.lp",
        check = {
            { "uci.network.interface.@wan.proto", "^static$"},
        },
        operations = function()
            return apply_mode("static", "static")
        end,
    },
    {
        name = "bridge",
        default = false,
        description = T"Bridge mode",
        view = "internet-bridged.lp",
        card = "003_internet_bridged.lp",
        check = {
            { "uci.network.config.wan_mode", "^bridge$"}
        },
        operations = function()
            return apply_mode("bridge", "bridge")
        end,
    },
}
