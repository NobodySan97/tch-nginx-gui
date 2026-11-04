--pretranslated: do not change this file
gettext.textdomain('webui-openvpn-server')

local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")
local format = string.format

local function file_exists(path)
  local file = io.open(path, "r")
  if file then
    file:close()
    return true
  end
  return false
end

if not file_exists("/usr/sbin/openvpn") and not file_exists("/etc/init.d/openvpn") then
  return
end
local content = {
  enabled = "uci.openvpn.openvpn.@server.enabled",
  client_enabled = "uci.openvpn.openvpn.@client.enabled",
  connected_clients = "rpc.openvpn.server.connected_clients",
}
content_helper.getExactContent(content)
local enabled = content.enabled == "1" and "1" or "0"
local status_text = enabled == "1" and T"OpenVPN server enabled" or T"OpenVPN server disabled"
local client_enabled = content.client_enabled == "1" and "1" or "0"
local client_text = client_enabled == "1" and T"OpenVPN client enabled" or T"OpenVPN client disabled"
local connected = tonumber(content.connected_clients) or 0
local modal_path
local session = ngx.ctx.session
if session and session:hasAccess("/modals/openvpn-server-modal.lp") then modal_path = "/modals/openvpn-server-modal.lp" end
ngx.print('<div class="span3" id="openvpn-card"><div class="smallcard">')
ngx.print(ui_helper.createCardHeader(T"OpenVPN", modal_path))
ngx.print('<div class="content card_bg" data-bg-text="&#xf023;">', ui_helper.createSimpleLight(enabled, status_text), '<p class="subinfos">')
ngx.print(format(N("<strong>%d client</strong> is connected", "<strong>%d clients</strong> are connected", connected), connected))
ngx.print('</p>', ui_helper.createSimpleLight(client_enabled, client_text), '<p class="subinfos">')
if client_enabled == "1" then
  local is_up = false
  local tunnel = io.open("/sys/class/net/tun1/operstate", "r")
  if tunnel then
    local state = tunnel:read("*l")
    tunnel:close()
    if state and state:match("up") then is_up = true end
  end
  ngx.print(is_up and T"Client tunnel is up" or T"Client tunnel is down")
end
ngx.print('</p></div></div></div>')

if modal_path then
ngx.print([===[
<script>
$(function () {
    var element = document.getElementById("openvpn-card");
    if (!element) return;
    function refresh() {
        return $.ajax({url: "/ajax/get_card.lua?modal=/modals/openvpn-server-modal.lp",
            type: "GET", dataType: "html", timeout: 8000, cache: false
        }).done(function (html) {
            if (document.getElementById("openvpn-card") !== element) return;
            // Keep the registered card element; discard scripts in the rendered response.
            var content = $("<div>").append($.parseHTML(html, document, false))
                .find("#openvpn-card > .smallcard > .content");
            if (content.length === 1) $(element).find(".content").replaceWith(content);
        });
    }
    new modgui.createAjaxUpdateCard("openvpn-card", null, "OpenvpnCardInterval", 30000, refresh);
});
</script>
]===])
end
