--pretranslated: do not change this file

-- Enable localization
gettext.textdomain('webui-core')

local proxy = require("datamodel")
local content_helper = require("web.content_helper")
local session = ngx.ctx.session
local format = string.format

local cui = {
	timestamp = "uci.version.version.@version[0].timestamp",
	gui_version = "rpc.system.modgui.gui_version",
	friendly_product_name = "uci.env.var.prod_friendly_name",
	provisioning_code = "uci.env.var.provisioning_code",
}

content_helper.getExactContent(cui)

local year = cui.timestamp or ""
local current_year = string.sub(tostring(year), 1, 4)
if current_year == "" then current_year = "2026" end

local product_name = cui.friendly_product_name or "Technicolor"
if cui.provisioning_code == "Telstra" then
	product_name = product_name:gsub("Technicolor", tostring(cui.provisioning_code))
elseif product_name == "AGHP" then
	product_name = "AGTHP"
end

local gui_ver = cui.gui_version or "9.7.61"

local lang_credit = ""

if tostring(gettext.language()) == "it-it" then
	lang_credit = "DarkNiko, bovirus"
elseif tostring(gettext.language()) == "de-de" then
	lang_credit = "meyergru"
end

local html = {}

html[#html+1] =		'<div id="footer" class="row">'
html[#html+1] =			'<div class="copyright">'
html[#html+1] =				format('<p>&copy; Technicolor %s</p>', current_year)
html[#html+1] =				format(T'<p>%s GUI Version ', product_name)
if session and session.hasAccess and session:hasAccess("/modals/changelog.lp") then
	html[#html+1] =					format('<a href data-toggle="modal" data-remote="modals/changelog.lp">%s</a>', gui_ver)
else
	html[#html+1] =					format('%s', gui_ver)
end
html[#html+1] =				'</p>'
html[#html+1] =				T'<p>Fork & Maintained by <font style="color:#0088cc;">NobodySan97</font> (<a target="_blank" href="https://ko-fi.com/nobodysan" style="color:#ff5e5b;font-weight:bold;"><i class="fa fa-coffee"></i> Support on Ko-fi</a>) &mdash; Based on original <font style="color:#0088cc;">Ansuel GUI</font> by <font style="color:#0088cc;">Ansuel</font> and <a href="https://github.com/NobodySan97/tch-nginx-gui/graphs/contributors">these GitHub users.</a><br/>Unlock Utility by <font style="color:#0088cc;">ADeltaX</font>'

if not ( tostring(gettext.language()) == "en-us" ) then
	html[#html+1] =			format(T' && Translated by <font style="color:#0088cc;">%s</font>',lang_credit)
end
html[#html+1] =				'</p>'
html[#html+1] =			'</div>'
html[#html+1] =		'</div>'

ngx.print(html)

ngx.print('\
<script>\
var processMsg=\'');  ngx.print(T"Processing"); ngx.print('\';\
var openMsg = \'');  ngx.print(T"Loading..."); ngx.print('\';\
var waitMsg = \'');  ngx.print(T"Please wait..."); ngx.print('\';\
var loginMsg =\'');  ngx.print(T"Login Expired. Reloading."); ngx.print('\';\
var connectionLost = \'');  ngx.print(T"Connection issue: "); ngx.print('\';\
var okButton = \'');  ngx.print(T"Ok"); ngx.print('\';\
var cancelButton = \'');  ngx.print(T"Cancel"); ngx.print('\';\
function httpErrorMessage(err){\
	switch(err.status){\
		case 500:\
			erromsg=\'');  ngx.print(T"Internal Server Error occured, please contact administrator"); ngx.print('\';\
			break;\
		case 404:\
			erromsg=\'');  ngx.print(T"The requested file is not found! Please try again after some time"); ngx.print('\';\
			break;\
		case 503:\
			erromsg=\'');  ngx.print(T"The server is currently unavailable, Please try again after some time"); ngx.print('\';\
			break;\
		case 408:\
			erromsg=\'');  ngx.print(T"The server timed out waiting for the request"); ngx.print('\';\
			break;\
		default:\
			erromsg=\'');  ngx.print(T"The request could not be performed due to some error"); ngx.print('\';\
	};\
	window.setTimeout(function(){\
		erromsg = \'<div style="margin-left:35%;margin-top:9%;"><span class="alert-error">\'+erromsg+\'</span></div>\';\
		var ht = $(\'.modal-body\').height();\
		ht = toString(ht).match(/\\d+/) > 230 ? ht:230;\
		$(\'.modal-body\').height(ht);\
		var tab = $(\'.modal-body ul\').html();\
		if(tab != undefined)\
			erromsg = \'<ul class="nav nav-tabs">\' + tab + \'</ul>\' + erromsg;\
		$(\'.modal-body\').html(erromsg);\
	},400);\
};\
</script>\
');
