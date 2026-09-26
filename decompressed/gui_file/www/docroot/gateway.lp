--pretranslated: do not change this file
 
-- Enable localization

local content_helper = require("web.content_helper")

local lp = require("web.lp")

local firstpage

local cui = {
    advanced = "uci.web.uiconfig.@uidefault.alwaysadvanced",
	gui_skin = "uci.modgui.gui.gui_skin",
	firstpage = "uci.modgui.gui.firstpage",
}
content_helper.getExactContent(cui)

local function snippet_exists(name)
	local f = io.open("/www/gateway-snippets/" .. name, "r")
	if f then f:close() return true end
	return false
end

if cui.firstpage == "stats" and snippet_exists("stats.lp") then
	firstpage = "stats.lp"
elseif cui.firstpage == "telstra" and snippet_exists("telstra-gui.lp") then
	firstpage = "telstra-gui.lp"
else
	firstpage = "cards.lp"
end

	lp.setpath("/www/gateway-snippets/")
if not firstpage:match("telstra") then
	lp.include("head-js-css.lp")

  ngx.print('\
<body>\
');
	lp.setpath("/www/gateway-snippets/")
	lp.include("header.lp")
end
	lp.include(firstpage)

if not firstpage:match("telstra") then
	lp.setpath("/www/gateway-snippets/")
	lp.include("footer.lp")
	
ngx.print('\
</body>\
</html>\
');
end