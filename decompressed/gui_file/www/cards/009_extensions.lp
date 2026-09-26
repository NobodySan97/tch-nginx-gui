--pretranslated: do not change this file

-- Enable localization
gettext.textdomain('webui-core')

local ui_helper = require("web.ui_helper")
local proxy = require("datamodel")
local content_helper = require("web.content_helper")
local insert, format = table.insert, string.format

local marketing_version = proxy.get("uci.version.version.@version[0].marketing_version")
local cputype_res = proxy.get("rpc.system.modgui.CPUtype")
local cputype = (cputype_res and cputype_res[1] and cputype_res[1].value) or ""

local extension_supported = 0

local function kernel_has_tun()
	local command = io.popen("[ -c /dev/net/tun ] || zcat /proc/config.gz 2>/dev/null | grep -q '^CONFIG_TUN=y$'; echo $?", "r")
	if not command then
		return false
	end
	local result = command:read("*line")
	command:close()
	return result == "0"
end

local function wireguard_supported()
	if kernel_has_tun() then return true end
	local command = io.popen("[ \"$(uname -r)\" = 4.1.52 ] && { [ \"$(uci -q get version.@version[0].version | cut -d- -f1-2)\" = 19.4.0866-3401052 ] || uci -q get version.@version[0].version | grep -q '^19\\.4'; }; echo $?", "r")
	if not command then return false end
	local result = command:read("*line")
	command:close()
	return result == "0"
end

local mv = 0
if marketing_version and marketing_version[1] and marketing_version[1].value then
	mv = tonumber(marketing_version[1].value:sub(1,4)) or 0
end
marketing_version = mv

local mapParams = {}

if marketing_version >= 16.3 then
	mapParams.luci_webui = "uci.modgui.app.luci_webui"
end
mapParams.aria2_webui = "uci.modgui.app.aria2_webui"
mapParams.transmission_webui = "uci.modgui.app.transmission_webui"
mapParams.adblock_application = "uci.modgui.app.adblock_app"
mapParams.rsyncd_application = "uci.modgui.app.rsyncd_app"
mapParams.openspeedtest_application = "uci.modgui.app.openspeedtest_app"
if cputype:match("^armv7") or cputype:match("^mips") then
	mapParams.l2tpipsec_application = "uci.modgui.app.l2tpipsec_app"
end
if cputype:match("^armv7") or cputype:match("^mips") then
	if kernel_has_tun() then
		mapParams.openvpn_application = "uci.modgui.app.openvpn_app"
	end
end
if cputype:match("^armv7") or cputype == "aarch64" or cputype == "arm64" then
	mapParams.speedtest_application = "uci.modgui.app.speedtest_app"
	mapParams.adguardhome_application = "uci.modgui.app.adguardhome_app"
	if wireguard_supported() then
		mapParams.wireguard_application = "uci.modgui.app.wireguard_app"
	end
	if kernel_has_tun() then
		mapParams.tailscale_application = "uci.modgui.app.tailscale_app"
	end
end
if cputype:match("^armv7") then
	mapParams.dumaos_application = "uci.modgui.app.dumaos_app"
end

content_helper.getExactContent(mapParams)

local StateParams = {}

for Params in pairs(mapParams) do
	extension_supported = extension_supported + 1
	if mapParams[Params] and mapParams[Params] == "1" then
		StateParams[Params] = "1"
	else
		StateParams[Params] = "0"
	end
end

local extension_items = {
	{ key = "luci_webui", title = T"LuCI" },
	{ key = "aria2_webui", title = T"Aria2" },
	{ key = "transmission_webui", title = T"Transmission" },
	{ key = "adblock_application", title = T"Adblock" },
	{ key = "rsyncd_application", title = T"Rsync" },
	{ key = "speedtest_application", title = T"Speedtest" },
	{ key = "adguardhome_application", title = T"AdGuard Home" },
	{ key = "openspeedtest_application", title = T"OpenSpeedTest" },
	{ key = "wireguard_application", title = T"WireGuard" },
	{ key = "l2tpipsec_application", title = T"L2TP/IPsec" },
	{ key = "openvpn_application", title = T"OpenVPN" },
	{ key = "tailscale_application", title = T"Tailscale" },
	{ key = "dumaos_application", title = T"DumaOS" },
}

local modalPath = nil
local switchName = nil
local session = ngx.ctx.session
if session:hasAccess("/modals/applications-modal.lp") and extension_supported > 0 then
	modalPath = "/modals/applications-modal.lp"
end
ngx.print('\
<div class="span3">\
  <div class="smallcard extensions-card" data-aos="zoom-in" data-aos-anchor-placement="center-bottom" data-aos-easing="ease-in-back">\
\
    ');  ngx.print( ui_helper.createCardHeader(T"Extensions", modalPath, switchName, nil) ); ngx.print('\
\
    <div class="content card_bg" data-bg-text="&#xf015;">\
	  <div class="divtable extensions-status-grid">\
\
      ');
local html = {}

for _, item in ipairs(extension_items) do
	if StateParams[item.key] ~= nil then
		html[#html + 1] = ui_helper.createSimpleLight(
			StateParams[item.key],
			item.title,
			{ span = { class = "simple-desc extension-status" } },
			nil
		)
	end
end

if extension_supported == 0 then
	html[#html + 1] = '<span class="simple-desc">'
	html[#html + 1] =	"<strong>"
	html[#html + 1] =		"No Extensions are supported on this device<br/>"
	html[#html + 1] =	"</strong>"
	html[#html + 1] = "</span>"
end
ngx.print(html)
ngx.print('\
\
	  </div>\
    </div>\
  </div>\
</div>\
');
