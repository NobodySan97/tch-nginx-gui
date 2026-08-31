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

html[#html + 1] = [[
<style>
  #modal-container .modal-action-close,
  #modal-container .modal-footer,
  .modal-action-close,
  .modal-footer {
    display: none !important;
  }
  .upgrade-finished .modal-action-close,
  .upgrade-finished.modal .modal-action-close,
  #modal-container.upgrade-finished .modal-action-close {
    display: block !important;
  }
  .upgrade-finished .modal-footer,
  .upgrade-finished.modal .modal-footer,
  #modal-container.upgrade-finished .modal-footer {
    display: block !important;
  }
  .upgrade-finished #close-config,
  .upgrade-finished #modal-no-change {
    display: inline-block !important;
  }
</style>
]]

html[#html + 1] = '<fieldset class="modal-body hide" id="upgrade-gui-bar" style="min-height: unset; margin-bottom: 15px;">'
html[#html + 1] = '<div class="alert alert-info" style="margin-bottom: 0;">'
html[#html + 1] = '<div style="display: flex; justify-content: space-between; font-weight: bold; margin-bottom: 6px;"><span id="update-text">'..T"Update in progress... Do not turn off your modem."..'</span><span id="progress-percent">0%</span></div>'
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
	var isUpgradeComplete = false;\
\
	var $activeModal = $("#modal-container, .modal");\
	$activeModal.data("backdrop", "static");\
	$activeModal.data("keyboard", false);\
	$(".modal-backdrop").off("click").css("cursor", "default");\
	$(document).off("keydown.bs.modal");\
	$(".modal-footer, .modal-action-close, #close-config").hide();\
\
	var CommandLogReadRefresh = function CommandLogReadRefresh(ElementBinding) {\
		if (!isUpgradeComplete) {\
			$(".modal-footer, .modal-action-close, #close-config").hide();\
		}\
		if(!requestInProgress){\
		requestInProgress=true;\
		$.ajax({\
            url:"/ajax/commandlogread.lua?auto_update=true",\
            data: [tch.elementCSRFtoken()],\
            complete: function(data) { requestInProgress=false },\
            dataType: "json"})\
			.done(function(data) {\
				var clean_log = (data.log || "")\
					.replace(/^[#=\\-O\\s]*\\d+\\.?\\d*%\\s*$/gm, "")\
					.replace(/^[#=\\-O\\s]+$/gm, "")\
					.replace(/\\n\\s*\\n/g, "\\n");\
				ElementBinding.log(clean_log);\
				var header_text = $("#header_title").text();\
				if (data.state && header_text != data.state) $("#header_title").text(data.state);\
				if (data.state == "Downloading" || data.progress !== undefined || data.state == "Extracting" || data.state == "In Progress" || data.state == "Clearing") {\
					$("#upgrade-gui-bar").removeClass("hide");\
					if (data.progress !== undefined) {\
						var pct = Math.round(data.progress);\
						$("#upgrade-progress-bar-fill").css("width", pct + "%").attr("aria-valuenow", pct);\
						$("#progress-percent").text(pct + "%");\
						$("#update-text").text("Download in corso (" + pct + "%)... Non spegnere il modem");\
					} else if (data.state == "Extracting") {\
						$("#upgrade-progress-bar-fill").css("width", "85%").removeClass("bar-warning").addClass("bar-info");\
						$("#progress-percent").text("85%");\
						$("#update-text").text("Estrazione e installazione file in corso...");\
					} else if (data.state == "In Progress") {\
						$("#upgrade-progress-bar-fill").css("width", "95%").removeClass("bar-warning").addClass("bar-info");\
						$("#progress-percent").text("95%");\
						$("#update-text").text("Finalizzazione aggiornamento...");\
					}\
				}\
				$("#show_progress").text($("#show_progress").text().replace(/[\\.]{10}/g, ""));\
				$("#show_progress").append(".");\
				if(data.state == "Complete" || data.state == "Failed" || data.state == "Error"){\
					isUpgradeComplete = true;\
					if (KoRequest.CommandLogReadInterval && KoRequest.CommandLogReadInterval.interval) {\
						clearInterval(KoRequest.CommandLogReadInterval.interval);\
					}\
					$("#upgrade-gui-bar").removeClass("hide");\
					$("#show_progress").text("");\
					if (data.state == "Complete") {\
						$("#upgrade-progress-bar-fill").css("width", "100%").removeClass("bar-warning bar-info").addClass("bar-success");\
						$("#progress-percent").text("100%");\
						$("#update-text").text("Aggiornamento completato con successo!");\
						$("#header_title").text("Aggiornamento Completato");\
					} else {\
						$("#upgrade-progress-bar-fill").css("width", "100%").removeClass("bar-warning bar-info").addClass("bar-danger");\
						$("#update-text").text("Aggiornamento non riuscito.");\
						$("#header_title").text("Errore");\
					}\
					$("body, .modal, #modal-container").addClass("upgrade-finished");\
					$(".modal-footer").show().css("display", "block");\
					$("#modal-no-change").show().css("display", "block");\
					$("#close-config").show().css("display", "inline-block");\
					$(".modal-action-close").show().css("display", "block");\
					$("#close-config, .modal-action-close, .btn-close").off("click").on("click", function(e) {\
						e.preventDefault();\
						tch.showProgress("Ricaricamento interfaccia in corso...");\
						setTimeout(function() {\
							window.location.reload(true);\
						}, 1500);\
					});\
				}\
			})\
            .fail(function(data) {\
				if(data.status==200 && data.responseText && data.responseText.indexOf("sign-me-in") !== -1){\
					isUpgradeComplete = true;\
					$("#header_title").text("Login Required");\
					$("#show_progress").text("");\
					$("body, .modal, #modal-container").addClass("upgrade-finished");\
					$(".modal-footer, .modal-action-close, #close-config").show().css("display", "block");\
					if (KoRequest.CommandLogReadInterval && KoRequest.CommandLogReadInterval.interval) {\
						clearInterval(KoRequest.CommandLogReadInterval.interval);\
					}\
				}\
				$("#show_progress").text($("#show_progress").text().replace(/[\\.]{10}/g, ""));\
				$("#show_progress").append(\'<span style="color: red;">.</span>\');\
            });\
		}\
	};\
\
	modgui.createAjaxUpdateCard("commandlogmodal",null,"CommandLogReadInterval",1000,CommandLogReadRefresh);\
  </script>\
');  ngx.print( ui_helper.createFooter() ); ngx.print('\
');
