--pretranslated: do not change this file

-- Localization
gettext.textdomain('webui-core')

local ui_helper = require("web.ui_helper")

local header = '<span id="header_title">'..T"Executing"..'</span><span id="show_progress"></span>'

ngx.print('\
\
');  ngx.print(ui_helper.createHeader(header, false, false))   ngx.print('\
<div class="modal-body update fake_console">\
  <form class="form-horizontal" id="commandlogmodal" method="post" action="/modals/command-log-read-modal.lp">\
        ')

local html = {}

html[#html + 1] = '<fieldset class="modal-body hide" id="upgrade-gui-bar" style="min-height: unset; margin-bottom: 15px;">'
html[#html + 1] = '<div class="alert alert-info" style="margin-bottom: 0;">'
html[#html + 1] = '<div style="display: flex; justify-content: space-between; font-weight: bold; margin-bottom: 6px;"><span id="update-text">'..T"Update in progress..."..'</span><span id="progress-percent">0%</span></div>'
html[#html + 1] = '  <div class="progress progress-striped active" style="margin-bottom: 0;">'
html[#html + 1] = '     <div id="upgrade-progress-bar-fill" class="bar bar-warning" role="progressbar" style="width: 0%;" aria-valuenow="0" aria-valuemin="0" aria-valuemax="100"></div>'
html[#html + 1] = '</div></div>'
html[#html + 1] = '</fieldset>'
html[#html + 1] = '<fieldset>'
html[#html + 1] = '<div style="white-space: pre-wrap" data-bind="log_text: log">'
html[#html + 1] = '</div>'
html[#html + 1] = '</fieldset>'

ngx.print(html)

ngx.print('\
  </form>\
</div>\
  <script>\
	var requestInProgress = false;\
	var CommandLogReadRefresh = function CommandLogReadRefresh(ElementBinding) {\
		$(".modal-footer,.modal-action-close").hide();\
		if(!requestInProgress){\
		requestInProgress=true;\
		$.ajax({\
            url:"/ajax/commandlogread.lua?auto_update=true",\
            data: [tch.elementCSRFtoken()],\
            complete: function(data) { requestInProgress=false },\
            dataType: "json"})\
			.done(function(data) {\
				ElementBinding.log(data.log);\
				var header_text = $("#header_title").text();\
				if (header_text != data.state) $("#header_title").text(data.state);\
				if (data.state == "Downloading" || data.progress !== undefined || data.state == "Extracting" || data.state == "In Progress" || data.state == "Clearing") {\
					$("#upgrade-gui-bar").removeClass("hide");\
					if (data.progress !== undefined) {\
						var pct = Math.round(data.progress);\
						$("#upgrade-progress-bar-fill").css("width", pct + "%").attr("aria-valuenow", pct);\
						$("#progress-percent").text(pct + "%");\
						$("#update-text").text("Download in corso (" + pct + "%)...");\
					} else if (data.state == "Extracting") {\
						$("#upgrade-progress-bar-fill").css("width", "85%").removeClass("bar-warning").addClass("bar-info");\
						$("#progress-percent").text("85%");\
						$("#update-text").text("Estrazione e installazione file...");\
					} else if (data.state == "In Progress") {\
						$("#upgrade-progress-bar-fill").css("width", "95%").removeClass("bar-warning").addClass("bar-info");\
						$("#progress-percent").text("95%");\
						$("#update-text").text("Finalizzazione aggiornamento...");\
					}\
				}\
				$("#show_progress").text($("#show_progress").text().replace(/[\\.]{10}/g, ""));\
				$("#show_progress").append(".");\
				if(data.state == "Complete"){\
					clearInterval(KoRequest.CommandLogReadInterval.interval);\
					$("#upgrade-gui-bar").removeClass("hide");\
					$("#upgrade-progress-bar-fill").css("width", "100%").removeClass("bar-warning bar-info").addClass("bar-success");\
					$("#progress-percent").text("100%");\
					$("#update-text").text("Aggiornamento completato con successo!");\
					$("#show_progress").text("");\
					$(".modal-footer").show();\
					$(".modal-footer,.modal-action-close").show();\
				}\
			})\
                        .fail(function(data) {\
                                if(data.status==200 && data.responseText.indexOf("sign-me-in") !== -1){\
                                        $("#header_title").text("Login Required");\
                                        $("#show_progress").text("");\
                                        $(".modal-footer").show();\
                                        $(".modal-footer,.modal-action-close").show();\
                                        clearInterval(KoRequest.CommandLogReadInterval.interval);\
                                }\
                                $("#show_progress").text($("#show_progress").text().replace(/[\\.]{10}/g, ""));\
                                $("#show_progress").append(\'<span style="color: red;">.</span>\');\
                        });}\
        };\
\
        modgui.createAjaxUpdateCard("commandlogmodal",null,"CommandLogReadInterval",1000,CommandLogReadRefresh);\
  </script>\
');  ngx.print( ui_helper.createFooter() ); ngx.print('\
');
