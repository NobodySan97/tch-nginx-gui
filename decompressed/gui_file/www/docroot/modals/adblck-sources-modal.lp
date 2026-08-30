--pretranslated: do not change this file

-- Enable localization
gettext.textdomain('webui-code')

local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local proxy = require("datamodel")
local format, untaint = string.format, string.untaint

if ngx.req.get_method() == "POST" then
  local args = ngx.req.get_post_args()
  local selected_sources = args.adb_sources
  local active_map = {}
  
  if type(selected_sources) == "table" then
    for _, s in ipairs(selected_sources) do
      active_map[untaint(s)] = true
    end
  elseif selected_sources then
    active_map[untaint(selected_sources)] = true
  end

  local all_sources = proxy.getPN("uci.adblock.source.", true) or {}
  for _, src in ipairs(all_sources) do
    local sname = src.path:match("uci%.adblock%.source%.@([^%.]+)%.")
    if sname then
      local should_enable = active_map[sname] and "1" or "0"
      proxy.set(src.path .. "enabled", should_enable)
    end
  end
  proxy.apply()
  os.execute("/etc/init.d/adblock reload &")
  message_helper.pushMessage(T"Sorgenti Adblock aggiornate. Ricaricamento in corso...", "success")
end

-- Read all sources from UCI
local sources_list = {}
local all_sources = proxy.getPN("uci.adblock.source.", true) or {}
for _, src in ipairs(all_sources) do
  local sname = src.path:match("uci%.adblock%.source%.@([^%.]+)%.")
  if sname then
    local url_obj = proxy.get(src.path .. "adb_src")
    local desc_obj = proxy.get(src.path .. "adb_src_desc")
    local en_obj = proxy.get(src.path .. "enabled")
    sources_list[#sources_list+1] = {
      name = sname,
      url = (url_obj and url_obj[1]) and url_obj[1].value or "",
      desc = (desc_obj and desc_obj[1]) and desc_obj[1].value or "",
      enabled = (en_obj and en_obj[1] and en_obj[1].value == "1"),
    }
  end
end

table.sort(sources_list, function(a,b) return a.name < b.name end)

local warn_box = {
  alert = {
    class = "alert alert-info",
    style = "text-align:center",
  }
}

ngx.print(ui_helper.createHeader("Adblock", false, true), '\
<div class="modal-body update">')
  local lp = require("web.lp")
  lp.setpath("/www/snippets/")
  lp.include("tabs-adblock.lp")
  ngx.print('\
  <form class="form-horizontal" method="post" action="modals/adblck-sources-modal.lp">',
    ui_helper.createMessages(message_helper.popMessages()),'\
    <fieldset><legend>',T"Sorgenti Blacklist DNS",'</legend>')
    ngx.print(ui_helper.createAlertBlock(T"Seleziona le liste desiderate. Consigliate: <strong>stevenblack, adguard, disconnect, adaway, yoyo</strong>.", warn_box))
    ngx.print('\
      <div class="control-group">\
        <table id="adb_sources" class="table table-striped table-bordered">\
          <thead>\
            <tr>\
              <th style="width:40px; text-align:center;">Attiva</th>\
              <th>Nome</th>\
              <th>Descrizione</th>\
              <th>URL Lista</th>\
            </tr>\
          </thead>\
          <tbody>')
          for _, src in ipairs(sources_list) do
            local checked = src.enabled and " checked" or ""
            ngx.print(format('<tr><td style="text-align:center;"><input type="checkbox" name="adb_sources" value="%s"%s></td><td><strong>%s</strong></td><td>%s</td><td style="word-break:break-all; font-size:11px;">%s</td></tr>',
              src.name, checked, src.name, src.desc, src.url))
          end
          ngx.print('\
          </tbody>\
        </table>\
      </div>\
    </fieldset>\
  </form>\
</div>\
<script>\
$().ready(function(){\
  $("#adb_sources input[type=checkbox]").on("change", function(){\
    $("#modal-no-change").hide();\
    $("#modal-changes").removeClass("hide").show();\
  });\
});\
</script>\
', ui_helper.createFooter())
