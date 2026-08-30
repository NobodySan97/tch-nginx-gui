--pretranslated: do not change this file

-- Enable localization
gettext.textdomain('webui-code')

local post_helper = require("web.post_helper")
local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local proxy = require("datamodel")

local vB = post_helper.validateBoolean

local mapParams = {
  adb_enabled = "uci.adblock.global.adb_enabled",
  adb_backup = "uci.adblock.global.adb_backup",
  adb_debug = "uci.adblock.global.adb_debug",
}

local mapValid = {
  adb_enabled = vB,
  adb_backup = vB,
  adb_debug = vB,
}

if ngx.req.get_method() == "POST" then
  local args = ngx.req.get_post_args()
  if args.action == "reload" then
    os.execute("/etc/init.d/adblock reload &")
    message_helper.pushMessage(T"Ricaricamento Adblock avviato in background", "success")
  end
end

local config, helpmsg = post_helper.handleQuery(mapParams, mapValid)
if not helpmsg then
  helpmsg = {}
end

ngx.print('\
');  ngx.print(ui_helper.createHeader("Adblock", false, true) ); ngx.print('\
<div class="modal-body update">')
  local lp = require("web.lp")
  lp.setpath("/www/snippets/")
  lp.include("tabs-adblock.lp")
  ngx.print('\
  <form class="form-horizontal" method="post" action="modals/adblck-config-modal.lp">',
    ui_helper.createMessages(message_helper.popMessages()),'\
    <fieldset><legend>',T"Stato e Configurazione Adblock",'</legend>',
      ui_helper.createSwitch(T"Abilita Adblock", "adb_enabled", config["adb_enabled"], nil, helpmsg["adb_enabled"]),
      ui_helper.createSwitch(T"Backup Cache Liste", "adb_backup", config["adb_backup"], nil, helpmsg["adb_backup"]),
      ui_helper.createSwitch(T"Modalità Debug", "adb_debug", config["adb_debug"], nil, helpmsg["adb_debug"]),'\
    </fieldset>\
  </form>\
  <form class="form-horizontal" method="post" action="modals/adblck-config-modal.lp" style="margin-top:15px;">\
    <input type="hidden" name="action" value="reload">\
    <div class="control-group">\
      <div class="controls">\
        <button type="submit" class="btn btn-primary"><i class="fa fa-refresh"></i> Ricarica e Aggiorna Liste Ora</button>\
      </div>\
    </div>\
  </form>\
</div>\
',ui_helper.createFooter())
