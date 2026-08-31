--pretranslated: do not change this file

-- Enable localization
gettext.textdomain('webui-core')

local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local format, untaint = string.format, string.untaint
local html_escape = require("web.web").html_escape

local function read_file(path)
  local f = io.open(path, "r")
  if not f then return "" end
  local c = f:read("*a") or ""
  f:close()
  return c
end

local function write_file(path, content)
  local f = io.open(path, "w+")
  if not f then return false end
  f:write(content)
  f:close()
  return true
end

if ngx.req.get_method() == "POST" then
  local args = ngx.req.get_post_args()
  local wl = untaint(args.whitelist or "")
  local bl = untaint(args.blacklist or "")
  write_file("/etc/adblock/adblock.whitelist", wl)
  write_file("/etc/adblock/adblock.blacklist", bl)
  os.execute("/etc/init.d/adblock reload &")
  message_helper.pushMessage(T"Custom lists saved successfully!", "success")
end

local wl_content = read_file("/etc/adblock/adblock.whitelist")
local bl_content = read_file("/etc/adblock/adblock.blacklist")

ngx.print(ui_helper.createHeader("Adblock", false, true), '\
<div class="modal-body update">')
  local lp = require("web.lp")
  lp.setpath("/www/snippets/")
  lp.include("tabs-adblock.lp")
  ngx.print('\
  <form class="form-horizontal" method="post" action="modals/adblck-lists-modal.lp">',
    ui_helper.createMessages(message_helper.popMessages()),'\
    <fieldset><legend>',T"Custom Lists (One domain per line)",'</legend>\
      <div class="control-group">\
        <label class="control-label"><strong>Whitelist</strong><br><small>Domini sempre permessi</small></label>\
        <div class="controls">\
          <textarea name="whitelist" rows="6" class="span5" placeholder="es. example.com&#10;google.com">',html_escape(wl_content or ""),'</textarea>\
        </div>\
      </div>\
      <div class="control-group">\
        <label class="control-label"><strong>Blacklist</strong><br><small>Domini sempre bloccati</small></label>\
        <div class="controls">\
          <textarea name="blacklist" rows="6" class="span5" placeholder="es. ads.evil.com&#10;tracking.domain.net">',html_escape(bl_content or ""),'</textarea>\
        </div>\
      </div>\
    </fieldset>\
  </form>\
</div>\
<script>\
$().ready(function(){\
  $("textarea[name=whitelist], textarea[name=blacklist]").on("input keyup change", function(){\
    $("#modal-no-change").hide();\
    $("#modal-changes").removeClass("hide").show();\
  });\
});\
</script>\
', ui_helper.createFooter())
