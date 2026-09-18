--pretranslated: do not change this file

-- Localization
gettext.textdomain('webui-core')

local ui_helper = require("web.ui_helper")

local header = '<span id="header_title">'..T"Executing"..'</span><span id="show_progress"></span>'

ngx.print(ui_helper.createHeader(header, false, false))

local html = {}

html[#html + 1] = [[
<div class="modal-body update fake_console">
  <form class="form-horizontal" id="commandlogmodal" method="post" action="/modals/command-log-read-modal.lp">
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

html[#html + 1] = '<fieldset class="modal-body" id="upgrade-gui-bar" style="min-height: unset; margin-bottom: 15px;">'
html[#html + 1] = '<div class="alert alert-info" style="margin-bottom: 0;">'
html[#html + 1] = '<div style="display: flex; justify-content: space-between; font-weight: bold; margin-bottom: 6px;"><span id="update-text">'..T"Update in progress... Do not turn off your modem."..'</span><span id="progress-percent">0%</span></div>'
html[#html + 1] = '  <div class="progress progress-striped active" style="margin-bottom: 0;">'
html[#html + 1] = '     <div id="upgrade-progress-bar-fill" class="bar bar-warning" role="progressbar" style="width: 5%;" aria-valuenow="5" aria-valuemin="0" aria-valuemax="100"></div>'
html[#html + 1] = '</div></div>'
html[#html + 1] = '</fieldset>'
html[#html + 1] = '<fieldset>'
html[#html + 1] = '<div id="command-log-text-container" style="white-space: pre-wrap; font-family: monospace; font-size: 12px; max-height: min(280px, 35vh); overflow-y: auto; scroll-behavior: smooth; background: rgba(0,0,0,0.05); padding: 8px; border-radius: 4px;" data-bind="log_text: log">'
html[#html + 1] = '[Inizializzazione] Avvio procedura di aggiornamento...'
html[#html + 1] = '</div>'
html[#html + 1] = '</fieldset>'

html[#html + 1] = [[
  </form>
</div>
<script>
	var requestInProgress = false;
	var isUpgradeComplete = false;
	var hasStartedExecution = false;
	var pollCount = 0;
	var consecutiveFailures = 0;

	var $activeModal = $("#modal-container, .modal");
	$activeModal.data("backdrop", "static");
	$activeModal.data("keyboard", false);
	$(".modal-backdrop").off("click").css("cursor", "default");
	$(document).off("keydown.bs.modal");
	$(".modal-footer, .modal-action-close, #close-config").hide();

	var CommandLogReadRefresh = function CommandLogReadRefresh(ElementBinding) {
		if (!isUpgradeComplete) {
			$(".modal-footer, .modal-action-close, #close-config").hide();
		}
		if (!requestInProgress && !isUpgradeComplete) {
			requestInProgress = true;
			$.ajax({
				url: "/ajax/commandlogread.lua?auto_update=true",
				type: "POST",
				data: {
					CSRFtoken: $("meta[name=CSRFtoken]").attr("content")
				},
				complete: function(data) { requestInProgress = false; },
				dataType: "json"
			})
			.done(function(data) {
				pollCount++;
				consecutiveFailures = 0;
				var clean_log = (data.log || "")
					.replace(/^[-#=O\s]*\d+\.?\d*%\s*$/gm, "")
					.replace(/^[-#=O\s]+$/gm, "")
					.replace(/\n\s*\n/g, "\n");
				if (!clean_log) {
					if (data.state == "Extracting") {
						clean_log = "[1/3] Download pacchetto completato (100%).\n[2/3] Estrazione e installazione file GUI in corso...";
					} else if (data.state == "In Progress") {
						clean_log = "[1/3] Download pacchetto completato.\n[2/3] Estrazione file completata.\n[3/3] Configurazione e migrazione overlay in corso...";
					} else if (data.state == "Downloading") {
						clean_log = "[1/3] Download pacchetto in corso" + (data.progress ? " (" + Math.round(data.progress) + "%)" : "") + "...";
					} else {
						clean_log = "[Inizializzazione] Avvio procedura di aggiornamento in corso...";
					}
				}
				if (ElementBinding && typeof ElementBinding.log === "function") {
					try { ElementBinding.log(clean_log); } catch(e) {}
				}
				$("#command-log-text-container").text(clean_log);
				var $logElem = $("#command-log-text-container, [data-bind*='log_text']");
				if ($logElem.length && $logElem[0]) {
					$logElem.scrollTop($logElem[0].scrollHeight);
				}

				var header_text = $("#header_title").text();

				if (data.state && header_text != data.state) $("#header_title").text(data.state);
				if (data.state == "Downloading" || data.progress !== undefined || data.state == "Extracting" || data.state == "In Progress" || data.state == "Clearing" || data.state == "Requested") {
					hasStartedExecution = true;
					$("#upgrade-gui-bar").removeClass("hide");
					if (data.progress !== undefined) {
						var pct = Math.round(data.progress);
						$("#upgrade-progress-bar-fill").css("width", pct + "%").attr("aria-valuenow", pct);
						$("#progress-percent").text(pct + "%");
						$("#update-text").text("Download in corso (" + pct + "%)... Non spegnere il modem");
					} else if (data.state == "Extracting") {
						$("#upgrade-progress-bar-fill").css("width", "85%").removeClass("bar-warning").addClass("bar-info");
						$("#progress-percent").text("85%");
						$("#update-text").text("Estrazione e installazione file in corso...");
					} else if (data.state == "In Progress") {
						$("#upgrade-progress-bar-fill").css("width", "95%").removeClass("bar-warning").addClass("bar-info");
						$("#progress-percent").text("95%");
						$("#update-text").text("Finalizzazione aggiornamento...");
					}
				}
				$("#show_progress").text($("#show_progress").text().replace(/\.{10}/g, ""));
				$("#show_progress").append(".");
				var isSuccess = (data.state == "Complete") || (hasStartedExecution && data.state == "Idle");
				var isFailed = (data.state == "Failed" || data.state == "Error");

				if (!isUpgradeComplete && (hasStartedExecution || pollCount > 3) && (isSuccess || isFailed)) {
					isUpgradeComplete = true;
					if (KoRequest.CommandLogReadInterval) {
						KoRequest.CommandLogReadInterval.active = false;
						if (KoRequest.CommandLogReadInterval.timer) clearTimeout(KoRequest.CommandLogReadInterval.timer);
						if (KoRequest.CommandLogReadInterval.interval) clearInterval(KoRequest.CommandLogReadInterval.interval);
					}
					$("#upgrade-gui-bar").removeClass("hide");
					$("#show_progress").text("");
					if (isSuccess) {
						var targetVer = (data.new_version_text && data.new_version_text !== "Unknown") ? data.new_version_text : "";
						if (!targetVer) {
							var matchVer = clean_log.match(/version_gui=([0-9]+\.[0-9]+\.[0-9]+)/i) || clean_log.match(/Online version:\s*([0-9]+\.[0-9]+\.[0-9]+)/i);
							if (matchVer && matchVer[1]) targetVer = matchVer[1];
						}
						var successMsg = "Aggiornamento completato con successo" + (targetVer ? " alla versione v" + targetVer : "") + "!";
						try { sessionStorage.setItem("gui_upgrade_success", successMsg); } catch(e) {}
						$("#upgrade-progress-bar-fill").css("width", "100%").removeClass("bar-warning bar-info").addClass("bar-success");
						$("#progress-percent").text("100%");
						$("#header_title").text("Aggiornamento Completato");
						var countdown = 3;
						$("#update-text").html("Aggiornamento completato con successo!<br><span style='font-size: 13px; font-weight: normal; opacity: 0.9;'>Reindirizzamento automatico al login in <strong id='redirect-countdown'>" + countdown + "</strong>s...</span>");
						var redirectTimer = setInterval(function() {
							countdown--;
							if ($("#redirect-countdown").length) $("#redirect-countdown").text(countdown);
							if (countdown <= 0) {
								clearInterval(redirectTimer);
								window.location.href = "/login.lp" + (targetVer ? "?upgraded_version=" + encodeURIComponent(targetVer) : "");
							}
						}, 1000);
					} else {
						$("#upgrade-progress-bar-fill").css("width", "100%").removeClass("bar-warning bar-info").addClass("bar-danger");
						$("#update-text").text("Aggiornamento non riuscito.");
						$("#header_title").text("Errore");
					}
					$("body, .modal, #modal-container").addClass("upgrade-finished");
					$(".modal-footer").show().css("display", "block");
					$("#modal-no-change").show().css("display", "block");
					$("#close-config").show().css("display", "inline-block");
					$(".modal-action-close").show().css("display", "block");
					$("#close-config, .modal-action-close, .btn-close").off("click").on("click", function(e) {
						e.preventDefault();
						if (typeof redirectTimer !== "undefined") clearInterval(redirectTimer);
						window.location.href = "/login.lp" + (targetVer ? "?upgraded_version=" + encodeURIComponent(targetVer) : "");
					});
				}
			})
			.fail(function(data) {
				consecutiveFailures++;
				if (data.status == 200 && data.responseText && data.responseText.indexOf("sign-me-in") !== -1) {
					isUpgradeComplete = true;
					try { sessionStorage.setItem("gui_upgrade_success", "Aggiornamento completato con successo!"); } catch(e) {}
					window.location.href = "/login.lp";
					return;
				}
				if (hasStartedExecution && consecutiveFailures >= 6) {
					if (!isUpgradeComplete) {
						isUpgradeComplete = true;
						try { sessionStorage.setItem("gui_upgrade_success", "Aggiornamento completato con successo!"); } catch(e) {}
						setTimeout(function() {
							window.location.href = "/login.lp";
						}, 2000);
					}
				}
				$("#show_progress").text($("#show_progress").text().replace(/\.{10}/g, ""));
				$("#show_progress").append('<span style="color: red;">.</span>');
			});

		}
	};

	modgui.createAjaxUpdateCard("commandlogmodal", null, "CommandLogReadInterval", 1000, CommandLogReadRefresh);
</script>
]]

ngx.print(html)
ngx.print(ui_helper.createFooter())
