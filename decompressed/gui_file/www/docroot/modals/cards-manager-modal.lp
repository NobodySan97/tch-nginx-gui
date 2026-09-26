--pretranslated: do not change this file

-- Localization
gettext.textdomain('webui-core')

local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local session = ngx.ctx.session
local format = string.format

if not session:hasAccess("/modals/modgui-modal.lp") and not session:hasAccess("/modals/cards-manager-modal.lp") then
    ngx.redirect("/login.lp")
    return
end

local function file_exists(path)
    local f = io.open(path, "r")
    if f then
        f:close()
        return true
    end
    return false
end

-- Catalog of configurable dashboard cards
local cards_catalog = {
    -- Category: network
    { id = "broadband", uci_sec = "broadband_card", file = "002_broadband.lp", title = T"Broadband", icon = "fas fa-tachometer-alt", cat = "network", desc = T"xDSL / Fiber / Ethernet WAN line status" },
    { id = "internet", uci_sec = "internet_card", file = "003_internet.lp", title = T"Internet Access", icon = "fas fa-globe", cat = "network", desc = T"WAN IP, Gateway, DNS and connection status" },
    { id = "wireless", uci_sec = "wireless_card", file = "004_wireless.lp", title = T"Wireless Wi-Fi", icon = "fas fa-wifi", cat = "network", desc = T"2.4GHz and 5GHz Wi-Fi networks and clients" },
    { id = "lan", uci_sec = "lan_card", file = "005_LAN.lp", title = T"Local Network (LAN)", icon = "fas fa-network-wired", cat = "network", desc = T"LAN IP address, subnet mask and DHCP status" },
    { id = "devices", uci_sec = "devices_card", file = "006_Devices.lp", title = T"Connected Devices", icon = "fas fa-laptop", cat = "network", desc = T"List of Ethernet and Wi-Fi connected devices" },
    { id = "wanservices", uci_sec = "wanservices_card", file = "007_wanservices.lp", title = T"WAN Services", icon = "fas fa-server", cat = "network", desc = T"DMZ, UPnP and Dynamic DNS (DDNS)" },
    { id = "xdsl", uci_sec = "xdsl_card", file = "093_xdsl.lp", title = T"xDSL Details", icon = "fas fa-chart-line", cat = "network", desc = T"Detailed bitrates, attenuation and SNR margins" },
    { id = "iproutes", uci_sec = "iproutes_card", file = "015_iproutes.lp", title = T"Static Routes", icon = "fas fa-route", cat = "network", desc = T"Custom IP routing tables and gateways" },
    { id = "relaysetup", uci_sec = "relaysetup_card", file = "018_relaysetup.lp", title = T"Relay Setup", icon = "fas fa-random", cat = "network", desc = T"DHCP and PPPoE Relay configurations" },
    { id = "lte", uci_sec = "lte_card", file = "010_lte.lp", title = T"Mobile / LTE", icon = "fas fa-signal", cat = "network", desc = T"3G / 4G USB backup modem connection", check_fn = function() return file_exists("/dev/cdc-wdm0") or file_exists("/dev/ttyUSB0") end },

    -- Category: security
    { id = "firewall", uci_sec = "firewall_card", file = "008_firewall.lp", title = T"Firewall", icon = "fas fa-shield-alt", cat = "security", desc = T"Firewall security level and active rules" },
    { id = "adblock", uci_sec = "adblock_card", file = "008_adblock.lp", title = T"Adblock", icon = "fas fa-ban", cat = "security", desc = T"DNS-level advertising and tracker blocking", check_fn = function() return file_exists("/etc/init.d/adblock") or file_exists("/etc/init.d/AdGuardHome") end },
    { id = "parental", uci_sec = "parental_card", file = "013_parental.lp", title = T"Parental Control", icon = "fas fa-user-lock", cat = "security", desc = T"Time and URL based device access restriction" },
    { id = "natalghelper", uci_sec = "natalghelper_card", file = "092_natalghelper.lp", title = T"NAT Helpers (ALG's)", icon = "fas fa-bolt", cat = "security", desc = T"Application Layer Gateways (FTP, SIP, RTSP, PPTP)", check_fn = function() return false end },
    { id = "tod", uci_sec = "tod_card", file = "015_tod.lp", title = T"Time of Day (ToD)", icon = "fas fa-clock", cat = "security", desc = T"Scheduled Wi-Fi and Internet access control" },

    -- Category: vpn
    { id = "wireguard", uci_sec = "wireguard_card", file = "016_wireguard.lp", title = T"WireGuard", icon = "fas fa-shield-virus", cat = "vpn", desc = T"Fast modern VPN server and tunnels", check_fn = function() return file_exists("/usr/bin/wg") or file_exists("/etc/init.d/wireguard") end },
    { id = "tailscale", uci_sec = "tailscale_card", file = "016_tailscale.lp", title = T"Tailscale", icon = "fas fa-project-diagram", cat = "vpn", desc = T"Mesh VPN overlay network client", check_fn = function() return file_exists("/usr/bin/tailscale") or file_exists("/opt/tailscale/tailscale") end },
    { id = "openvpnserver", uci_sec = "openvpnserver_card", file = "015_openvpn-server.lp", title = T"OpenVPN Server", icon = "fas fa-key", cat = "vpn", desc = T"Secure OpenVPN server for remote access", check_fn = function() return file_exists("/usr/sbin/openvpn") or file_exists("/etc/init.d/openvpn") end },
    { id = "assistance", uci_sec = "assistance_card", file = "010_assistance.lp", title = T"Remote Assistance", icon = "fas fa-hands-helping", cat = "vpn", desc = T"Remote operator assistance access" },

    -- Category: voice
    { id = "telephony", uci_sec = "telephony_card", file = "008_telephony.lp", title = T"Telephony (VoIP)", icon = "fas fa-phone", cat = "voice", desc = T"VoIP status, lines and incoming/outgoing calls" },
    { id = "asterisk", uci_sec = "asterisk_card", file = "008_asterisk.lp", title = T"Asterisk PBX", icon = "fas fa-headset", cat = "voice", desc = T"Asterisk internal IP-PBX switchboard", check_fn = function() return file_exists("/etc/init.d/asterisk") or file_exists("/usr/sbin/asterisk") end },

    -- Category: sharing
    { id = "contentsharing", uci_sec = "contentsharing_card", file = "012_contentsharing.lp", title = T"Content Sharing", icon = "fas fa-share-alt", cat = "sharing", desc = T"USB file sharing via Samba, FTP and DLNA", check_fn = function() return file_exists("/usr/sbin/smbd") or file_exists("/etc/init.d/samba") end },
    { id = "printersharing", uci_sec = "printersharing_card", file = "012_printersharing.lp", title = T"Printer Sharing", icon = "fas fa-print", cat = "sharing", desc = T"USB printer server sharing via CUPS / p910nd", check_fn = function() return file_exists("/usr/sbin/p910nd") end },

    -- Category: system
    { id = "diagnostics", uci_sec = "diagnostics_card", file = "009_diagnostics.lp", title = T"Diagnostics", icon = "fas fa-stethoscope", cat = "system", desc = T"Ping, traceroute, TCPdump and connection tests" },
    { id = "extensions", uci_sec = "extensions_card", file = "009_extensions.lp", title = T"Applications / Extensions", icon = "fas fa-cubes", cat = "system", desc = T"Install and manage additional modular apps" },
    { id = "usermgr", uci_sec = "usermgr_card", file = "011_usermgr.lp", title = T"User Manager", icon = "fas fa-users-cog", cat = "system", desc = T"Manage GUI users and access privileges" },
    { id = "qos", uci_sec = "qos_card", file = "008_qos.lp", title = T"QoS (Quality of Service)", icon = "fas fa-tasks", cat = "system", desc = T"Bandwidth queues and traffic prioritization" },
    { id = "eco", uci_sec = "eco_card", file = "020_eco.lp", title = T"Eco Mode", icon = "fas fa-leaf", cat = "system", desc = T"Energy saving, LED timers and CPU scaling" },
    { id = "cwmpconf", uci_sec = "cwmpconf_card", file = "090_cwmpconf.lp", title = T"CWMP / TR-069", icon = "fas fa-satellite-dish", cat = "system", desc = T"Operator remote management protocols" },
    { id = "system", uci_sec = "system_card", file = "091_system.lp", title = T"System", icon = "fas fa-cogs", cat = "system", desc = T"Cron jobs, init services, log viewer and reboot" },
    { id = "nfc", uci_sec = "nfc_card", file = "016_nfc.lp", title = T"NFC", icon = "fas fa-rss", cat = "system", desc = T"Near Field Communication pairing", check_fn = function() return false end },
}

local categories = {
    { id = "network", title = T"Network & Connectivity", icon = "fas fa-network-wired" },
    { id = "security", title = T"Security & Firewall", icon = "fas fa-shield-alt" },
    { id = "vpn", title = T"VPN & Remote Access", icon = "fas fa-lock" },
    { id = "voice", title = T"Voice & Telephony", icon = "fas fa-phone-alt" },
    { id = "sharing", title = T"Sharing & USB", icon = "fas fa-folder-open" },
    { id = "system", title = T"System & Tools", icon = "fas fa-sliders-h" },
}

local proxy = require("datamodel")
local uci = require("uci"):cursor()

local untaint = string.untaint or function(x) return x end

-- Handle POST Save
if ngx.req.get_method() == "POST" then
    ngx.req.read_body()
    local post_args = ngx.req.get_post_args()
    local f = io.open("/tmp/cards_visibility.tmp", "w")
    if f then
        for _, card in ipairs(cards_catalog) do
            local raw_val = post_args[card.id]
            local val = raw_val and untaint(raw_val) or nil
            -- If switch was ON (val == "1"), card is visible (hide='0'). Otherwise hidden (hide='1')
            local hide_val = (val == "1") and "0" or "1"
            f:write(string.format("%s=%s\n", card.uci_sec, hide_val))
        end
        f:close()
        proxy.set("rpc.system.modgui.utility.sendcmd", "setCardsVisibility_sync")
        proxy.apply()
    end
    message_helper.pushMessage(T"Dashboard cards configuration saved successfully.", "success")
end

-- Read current card visibility states from UCI
local card_states = {}
for _, card in ipairs(cards_catalog) do
    local hide_val = uci:get("web", card.uci_sec, "hide")
    -- Default is shown (hide='0' or missing -> "1"), hidden is "0"
    card_states[card.id] = (hide_val == "1") and "0" or "1"
end

-- Build auto-detect map for unused services
local auto_detect_map = {}
for _, card in ipairs(cards_catalog) do
    if card.check_fn then
        auto_detect_map[card.id] = card.check_fn() and "1" or "0"
    else
        auto_detect_map[card.id] = "1"
    end
end

ngx.print(ui_helper.createHeader(T"Dashboard Cards Manager", false, false))
ngx.print('\
<div class="modal-body update">\
')
ngx.print(ui_helper.createMessages(message_helper.popMessages()))
ngx.print('\
<style>\
  .card-mgr-actions { margin-bottom: 20px; display: flex; gap: 10px; flex-wrap: wrap; }\
  .card-mgr-item { display: flex; align-items: center; justify-content: space-between; padding: 10px 14px; margin-bottom: 8px; border-radius: 8px; background: rgba(0,0,0,0.02); border: 1px solid rgba(0,0,0,0.06); transition: all 0.2s ease; }\
  .card-mgr-item:hover { background: rgba(0,0,0,0.04); }\
  .card-mgr-info { display: flex; align-items: center; gap: 12px; flex: 1; min-width: 0; }\
  .card-mgr-icon { width: 34px; height: 34px; border-radius: 8px; background: #eef2f7; color: #3b5998; display: flex; align-items: center; justify-content: center; font-size: 16px; flex-shrink: 0; }\
  .card-mgr-text { display: flex; flex-direction: column; min-width: 0; }\
  .card-mgr-title { font-weight: 600; font-size: 14px; color: #2c3e50; }\
  .card-mgr-desc { font-size: 11px; color: #7f8c8d; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; max-width: 380px; }\
  .card-mgr-category { margin-top: 18px; margin-bottom: 10px; font-weight: 700; font-size: 15px; color: #34495e; border-bottom: 2px solid #eaeded; padding-bottom: 6px; display: flex; align-items: center; gap: 8px; }\
  .card-mgr-category i { color: #3498db; }\
  .card-mgr-essential { background: rgba(46, 204, 113, 0.08); border-left: 4px solid #2ecc71; }\
</style>\
\
<form class="form-horizontal" method="post" action="modals/cards-manager-modal.lp" id="form-cards-manager">\
  <fieldset>\
    <legend>' .. T"Customize Dashboard Cards" .. '</legend>\
    <p class="help-block">' .. T"Enable or disable the cards you want to display on the main router dashboard. Essential system cards (Gateway and GUI Settings) are always enabled." .. '</p>\
\
    <div class="card-mgr-actions">\
      <button type="button" class="btn btn-small btn-success" id="btn-cards-show-all"><i class="fas fa-check-double"></i> ' .. T"Show All" .. '</button>\
      <button type="button" class="btn btn-small btn-info" id="btn-cards-autodetect"><i class="fas fa-magic"></i> ' .. T"Smart Auto-Detect" .. '</button>\
      <button type="button" class="btn btn-small" id="btn-cards-hide-optional"><i class="fas fa-filter"></i> ' .. T"Hide Optional" .. '</button>\
    </div>\
')

for _, cat in ipairs(categories) do
    ngx.print(format('<div class="card-mgr-category"><i class="%s"></i> %s</div>', cat.icon, cat.title))
    for _, card in ipairs(cards_catalog) do
        if card.cat == cat.id then
            local is_checked = (card_states[card.id] == "1")
            local switch_class = is_checked and "switchOn" or "switchOff"
            local switcher_class = is_checked and "switcherOn" or "switcherOff"
            local switch_val = is_checked and "1" or "0"

            ngx.print(format([[
            <div class="card-mgr-item" data-card-id="%s" data-autodetect="%s">
              <div class="card-mgr-info">
                <div class="card-mgr-icon"><i class="%s"></i></div>
                <div class="card-mgr-text">
                  <span class="card-mgr-title">%s</span>
                  <span class="card-mgr-desc">%s</span>
                </div>
              </div>
              <div class="control-group" style="margin: 0;">
                <div class="switch %s" data-placement="left">
                  <div class="switcher %s" texton="%s" textoff="%s" valon="1" valoff="0"></div>
                  <input class="hide card-switch-input" value="%s" name="%s" id="switch_%s" type="hidden">
                </div>
              </div>
            </div>
            ]], 
            card.id,
            auto_detect_map[card.id] or "1",
            card.icon,
            card.title,
            card.desc or "",
            switch_class,
            switcher_class,
            T"ON",
            T"OFF",
            switch_val,
            card.id,
            card.id
            ))
        end
    end
end

ngx.print('\
  </fieldset>\
</form>\
\
<script>\
(function(){\
  function setSwitchState(container, enable) {\
    var sw = container.find(".switch");\
    var switcher = sw.find(".switcher");\
    var inp = sw.find("input");\
    if (enable) {\
      sw.removeClass("switchOff").addClass("switchOn");\
      switcher.removeClass("switcherOff").addClass("switcherOn");\
      inp.val("1").trigger("change");\
    } else {\
      sw.removeClass("switchOn").addClass("switchOff");\
      switcher.removeClass("switcherOn").addClass("switcherOff");\
      inp.val("0").trigger("change");\
    }\
    $("#modal-no-change").addClass("hide").hide();\
    $("#modal-changes").removeClass("hide").show();\
  }\
\
  $(document).on("click", "#form-cards-manager .switch", function(){\
    $("#modal-no-change").addClass("hide").hide();\
    $("#modal-changes").removeClass("hide").show();\
  });\
\
  $(document).on("click", "#save-config", function(){\
    window._cardsManagerSaved = true;\
  });\
  $(document).on("hidden", ".modal", function(){\
    if (window._cardsManagerSaved) {\
      window._cardsManagerSaved = false;\
      window.location.reload(true);\
    }\
  });\
\
  $(document).on("click", "#btn-cards-show-all", function(e){\
    e.preventDefault();\
    $(".card-mgr-item").each(function(){\
      setSwitchState($(this), true);\
    });\
  });\
\
  $(document).on("click", "#btn-cards-autodetect", function(e){\
    e.preventDefault();\
    $(".card-mgr-item").each(function(){\
      var shouldEnable = $(this).attr("data-autodetect") === "1";\
      setSwitchState($(this), shouldEnable);\
    });\
  });\
\
  $(document).on("click", "#btn-cards-hide-optional", function(e){\
    e.preventDefault();\
    var optionalCards = ["natalghelper", "printersharing", "contentsharing", "assistance", "tod", "nfc", "lte", "relaysetup", "asterisk", "tailscale", "wireguard", "openvpnserver", "adblock"];\
    $(".card-mgr-item").each(function(){\
      var cardId = $(this).attr("data-card-id");\
      if (optionalCards.indexOf(cardId) !== -1) {\
        setSwitchState($(this), false);\
      }\
    });\
  });\
})();\
</script>\
</div>\
')

ngx.print(ui_helper.createFooter())
