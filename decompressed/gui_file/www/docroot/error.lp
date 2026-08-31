--pretranslated: do not change this file

local content_helper = require("web.content_helper")
local session = ngx.ctx.session

local status, err
if ngx.req.get_method() == "GET" then
	err = ngx.req.get_uri_args().err
	status = tonumber(ngx.req.get_uri_args().status)
end

local cui = {
    advanced = "uci.web.uiconfig.@uidefault.alwaysadvanced",
	gui_skin = "uci.modgui.gui.gui_skin",
	gui_version = "rpc.system.modgui.gui_version",
}
content_helper.getExactContent(cui)

local error_code = {
	[403] = "FORBIDDEN",
	[500] = "INTERNAL_SERVER_ERROR",
	[200] = "HTTP_OK",
	[404] = "NOT_FOUND",
}

if session and not err then
	status = 500
	err = session:retrieve("lasterr")
end

if not err then
	err = ngx.header.error_msg or ""
end

if not status then
	status = ngx.status or 200
end

local status_detail = error_code[status] or "UNKNOWN"

ngx.print([[<!DOCTYPE HTML>
<html lang="it">
  <head>
    <meta http-equiv="X-UA-Compatible" content="IE=Edge,chrome=1">
    <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1">
    <meta charset="UTF-8">
    <meta name="Advanced" content="]], cui.advanced or "0", [[">
    <link href="/css/font-awesome-all-5.7.2.css?version=]], cui.gui_version or "1", [[" rel="stylesheet">
    <link href="/css/gw.css?version=]], cui.gui_version or "1", [[" rel="stylesheet">
    <link rel="shortcut icon" type="image/x-icon" href="/img/favicon.ico">
    <link href="/css/responsive.css?version=]], cui.gui_version or "1", [[" rel="stylesheet">
    <link rel="stylesheet" href="/css/aos.css?version=]], cui.gui_version or "1", [[">
    <link rel="stylesheet" href="/theme/]], cui.gui_skin or "green", [[/style.css?version=]], cui.gui_version or "1", [[">
    <title>Gateway - Error</title>
    <script src="/js/jquery.min.js?version=]], cui.gui_version or "1", [["></script>
    <script src="/js/main-min-nojquery.js?version=]], cui.gui_version or "1", [["></script>
  </head>
  <body>
    <div class="container">
      <div class="row" style="justify-content: center; margin-top: 50px;">
        <div class="span6" id="error-card">
          <div class="login" style="border-radius: 16px; box-shadow: 0 10px 25px rgba(0,0,0,0.15); overflow: hidden;">
            <form class="form-horizontal">
              <div class="login_bg" data-bg-text="&#xf071;">
                <div style="z-index: 2; position: relative; padding: 24px;">
                  <fieldset>
                    <h2>Error ]], status, [[ : ]], status_detail, [[</h2>
                    <div class="control-group" style="margin: 20px 0; color: #64748b;">
                      ]], err, [[
                    </div>
                  </fieldset>
                </div>
              </div>
            </form>
            <div style="padding: 0 24px 24px 24px;">
              <a href="/" class="btn btn-primary btn-large" style="width: 100%; box-sizing: border-box; text-align: center;">Go Back</a>
            </div>
          </div>
        </div>
      </div>
    </div>
  </body>
</html>]])
