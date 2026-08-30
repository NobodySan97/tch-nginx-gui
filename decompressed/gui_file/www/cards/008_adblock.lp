--pretranslated: do not change this file

-- Enable localization
gettext.textdomain('webui-core')

local adblock_helper = require("adblock_helper")
local ui_helper = require("web.ui_helper")
local session = ngx.ctx.session
local modalPath = "/modals/adblck-config-modal.lp"

local modal_link = nil
if session:hasAccess(modalPath) then
  modal_link = modalPath
end

local html = adblock_helper.getAdblockCardHTML()
ngx.print('\
<div class="span3">\
  <div class="smallcard" data-aos="zoom-in" data-aos-anchor-placement="center-bottom" data-aos-easing="ease-in-back">\
    ',ui_helper.createCardHeader(T"Adblock",modal_link,nil,nil,{icon={class="fa fa-filter"}}),'\
    <div class="content card_bg adblock-card-content" data-bg-text="&#xf0b0;">\
      <div class="divtable">\
        ',table.concat(html, "\n"),'\
      </div>\
    </div>\
  </div>\
</div>\
<script>\
var adbFuncID;\
function updateAdblockCard(){\
  $.post("/ajax/adblck-status.lua", [tch.elementCSRFtoken()], function(data){\
    $(".adblock-card-content").find(".divtable").html(data["html"]);\
  }, "json")\
  .fail(function(response){\
    if(response.status==403||response.status==404){clearInterval(adbFuncID);}\
  });\
}\
$().ready(function(){adbFuncID=setInterval(updateAdblockCard,15000);addRegisteredInterval(adbFuncID);});\
</script>\
')
