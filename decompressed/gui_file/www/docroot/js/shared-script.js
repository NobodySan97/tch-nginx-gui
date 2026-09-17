
window.registeredIntervals = window.registeredIntervals || [];
window.addRegisteredInterval = window.addRegisteredInterval || function(id) {
    if (id) window.registeredIntervals.push(id);
};
window.clearKoInterval = window.clearKoInterval || function() {
    if (window.registeredIntervals && window.registeredIntervals.length > 0) {
        window.registeredIntervals.forEach(function(id) { clearInterval(id); });
        window.registeredIntervals = [];
    }
};

var KoRequest = {};
var connectionissue = 0;

var modgui = modgui || {};
!function (module) {

	function standardCloseAction() {
		tch.showProgress(waitMsg);
		window.location.reload(true);
	}
	function postAction(action, logModal, customCloseAction, customTarget) {
		var onClose = ( typeof customCloseAction === "function" ) && customCloseAction || function() {
			tch.showProgress(waitMsg);
			window.location.reload(true);
		}

		var target = customTarget ? customTarget : $(".modal form").attr("action");
		$.post(
			target, {
				action: action,
				CSRFtoken: $("meta[name=CSRFtoken]").attr("content")
			},
			function() {
				if(logModal){
					clearKoInterval();
					$(document).one('shown shown.bs.modal', '.modal', function() {
						var $m = $(this);
						$m.data('backdrop', 'static').data('keyboard', false);
						$(".modal-backdrop").off('click').css('cursor', 'default');
						$(".modal-footer, .modal-action-close, #close-config").hide();
						$("#close-config, .modal-action-close").off("click").on("click", function() {
							onClose();
						});
					});
					tch.openModal("/modals/command-log-read-modal.lp");
				}
			},
			"json"
		);
		return false;
	}

	function createAjaxUpdateCard(CardIdRefresh, ajaxLink, IntervalVar, RefreshTime, CustomRefreshFunction) {

		var element = document.getElementById(CardIdRefresh);
		if (!element) return ;

		var ElementBinding = {};
		var ElementBindingList = [];
		var ObserveElement;
		$("#" + CardIdRefresh).find("[data-bind]").each(function () {
			ObserveElement = $(this).data("bind").split(":")[1].trim();
			ElementBindingList.push(ObserveElement);
			ElementBinding[ObserveElement] = ko.observable();
		});

		var arrayLength = ElementBindingList.length;
		var fullUrl = "";
		if (ajaxLink && typeof ajaxLink === "string") {
			var updateLink = (ajaxLink.indexOf("?") !== -1 ? "&" : "?") + "auto_update=true";
			fullUrl = ajaxLink + updateLink;
		}

		if (KoRequest[IntervalVar]) {
			if (KoRequest[IntervalVar].timer) clearTimeout(KoRequest[IntervalVar].timer);
			if (KoRequest[IntervalVar].interval) clearInterval(KoRequest[IntervalVar].interval);
			if (KoRequest[IntervalVar].xhr && KoRequest[IntervalVar].xhr.readyState !== 4) {
				KoRequest[IntervalVar].xhr.abort();
			}
		}

		var reqState = {
			active: true,
			timer: null,
			interval: null,
			xhr: null,
			binding: ElementBinding,
			refreshTime: RefreshTime || 3000,
			url: ajaxLink,
			customFn: CustomRefreshFunction
		};
		KoRequest[IntervalVar] = reqState;

		function scheduleNext() {
			if (!reqState.active || document.hidden) return;
			reqState.timer = setTimeout(executePoll, reqState.refreshTime);
			reqState.interval = reqState.timer;
		}

		function executePoll() {
			if (!reqState.active || document.hidden) return;

			if (typeof CustomRefreshFunction === "function") {
				try {
					CustomRefreshFunction(ElementBinding);
				} catch (err) {
					console.error("Error in custom refresh function:", err);
				}
				scheduleNext();
				return;
			}

			if (!fullUrl) return;

			reqState.xhr = $.ajax({
				url: fullUrl,
				type: "POST",
				data: [tch.elementCSRFtoken()],
				dataType: "json",
				timeout: 8000
			})
			.done(function (data) {
				if (!reqState.active) return;
				for (var i = 0; i < arrayLength; i++) {
					var key = ElementBindingList[i];
					if (data && data[key] !== undefined && ElementBinding[key]() !== data[key]) {
						ElementBinding[key](data[key]);
					}
				}
				if (connectionissue === 1) {
					if ($("#popUp").is(":visible")) tch.removeProgress();
					connectionissue = 0;
				}
			})
			.fail(function (data, textStatus) {
				if (textStatus === "abort") return;
				connectionissue = 1;
				if (data && data.status === 200 && data.responseText && data.responseText.indexOf("sign-me-in") !== -1) {
					if (!$("#popUp").is(":visible")) tch.showProgress(loginMsg);
					window.location.href = "/";
				}
			})
			.always(function () {
				reqState.xhr = null;
				scheduleNext();
			});
		}

		executePoll();

		if (!ko.dataFor(element))
			ko.applyBindings(ElementBinding, element);
	}

	function linkCheckUpdate() {
		$(".check_update").on("click", function (e) {
			e.stopPropagation();
			if (KoRequest.CheckVer) return;
			postAction("checkver", null, null, '/modals/modgui-modal.lp?auto_update=true');
			$(".check_update_spinner").addClass("fa-spin");

			var pollCount = 0;
			var hasSeenChecking = false;

			function stopCheckVer() {
				if (KoRequest.CheckVer && KoRequest.CheckVer.interval) {
					clearInterval(KoRequest.CheckVer.interval);
				}
				KoRequest.CheckVer = null;
				$(".check_update_spinner").removeClass("fa-spin");
			}

			function applyVersionUpdate(versionText, isOutdated) {
				if (versionText && versionText !== "" && versionText !== "Unknown") {
					$(".gui_version_status").removeClass("green").addClass("yellow");
					$("#upgradebtn").removeClass("hide");
					$(".gui_version_status_text").text(gui_var.gui_outdated);
					$("#upgrade-alert").removeClass("hide");
					$("#new-version-text").text(versionText);
				} else {
					$(".gui_version_status").removeClass("yellow").addClass("green");
					$(".gui_version_status_text").text(gui_var.gui_updated);
					$("#upgrade-alert").addClass("hide");
				}
				$(".gui_version_status_text").parent().fadeOut(150).fadeIn(150);
			}

			KoRequest.CheckVer = {
				interval: setInterval(function () {
					pollCount++;
					// Hard watchdog timeout after 20 seconds
					if (pollCount > 20) {
						stopCheckVer();
						return;
					}

					$.ajax({
						url: "/ajax/commandlogread.lua?auto_update=true",
						data: [tch.elementCSRFtoken()],
						type: "POST",
						dataType: "json",
						timeout: 4000,
						success: function (data) {
							if (!data) return;

							if (data.state === "Checking" || data.state === "Requested") {
								hasSeenChecking = true;
							}

							if (data.new_version_text !== undefined) {
								applyVersionUpdate(data.new_version_text, data.outdated_ver);
							}

							if (data.state === "Complete" || (hasSeenChecking && data.state === "Idle")) {
								stopCheckVer();
							}
						},
						error: function () {
							if (pollCount > 15) {
								stopCheckVer();
							}
						}
					});
				}, 1000)
			};
		});
	};

	function freshStyle(stylesheet) {
		$("#theme_skin").attr("href", "/theme/" + stylesheet);
	}

	function scrollFunction() {
		if (document.body.scrollTop > 60 || document.documentElement.scrollTop > 60) {
			$("#scroll-up").removeClass("hide");
			$("#scroll-down").addClass("hide");
		} else {
			$("#scroll-up").addClass("hide");
			$("#scroll-down").removeClass("hide");
		}
	}

	function clearKoInterval() {
		if (window.registeredIntervals && window.registeredIntervals.length > 0) {
			window.registeredIntervals.forEach(function(id) {
				clearTimeout(id);
				clearInterval(id);
			});
			window.registeredIntervals = [];
		}
		Object.keys(KoRequest).forEach(function(key) {
			var req = KoRequest[key];
			if (req) {
				req.active = false;
				if (req.timer) clearTimeout(req.timer);
				if (req.interval) clearInterval(req.interval);
				if (req.xhr && req.xhr.readyState !== 4) req.xhr.abort();
			}
		});
	}

	function restartKoInterval() {
		Object.keys(KoRequest).forEach(function(key) {
			var req = KoRequest[key];
			if (req && !req.active) {
				createAjaxUpdateCard(key, req.url || null, key, req.refreshTime, req.customFn);
			}
		});
	}

	// Resolve mac to vendor
	// Take mac and the JQuery div object to put the vendor
	function getVendorFromMac(mac, div) {
		div.addClass("fa fa-sync fa-spin");
		$.ajax({
			url: "/modals/modgui-modal.lp?auto_update=true",
			method: 'POST',
			data: {
				action: 'getVendor',
				mac: mac,
				CSRFtoken: $("meta[name=CSRFtoken]").attr("content")
			},
			error: function() {
				div.removeClass("fa fa-sync fa-spin");
				div.text('Error');
			},
			success: function (data) {
				div.removeClass("fa fa-sync fa-spin");
				div.text(data || 'Unknown');
			}
		});
	}

	module.postAction = postAction,
	module.createAjaxUpdateCard = createAjaxUpdateCard,
	module.linkCheckUpdate = linkCheckUpdate,
	module.freshStyle = freshStyle,
	module.scrollFunction = scrollFunction,
	module.clearKoInterval = clearKoInterval,
	module.restartKoInterval = restartKoInterval,
	module.getVendorFromMac = getVendorFromMac
}
(modgui);

window.onscroll = function () {
	modgui.scrollFunction()
};

$(function () {
	$("a[href*=\'#\']").on("click", function (e) {
		e.preventDefault();
		$("html, body").animate({
			scrollTop: $($(this).attr("href")).offset().top
		}, 500, "linear");
	});

	$(document).on('mouseenter', 'td[data-toggle="tooltip_mac"]', function () {
		var elem = this;
		var mac = $(elem).children("#mac_data").text();
		$(elem).append('<div class="tooltip bottom fade in"><div class="tooltip-arrow"></div><div class="tooltip-inner">'+
		mac+'</br>'+
		'<div data-type="vendor"></div>'
		+'</div></div>');
		modgui.getVendorFromMac(mac,$(elem).children('.tooltip').children('.tooltip-inner').children('div[data-type="vendor"]'));
	}).on('mouseleave', 'td[data-toggle="tooltip_mac"]', function () {
		$('.tooltip').remove();
	});

	if (gui_var.randomcolor == "1") {
		setInterval(function () {
			var colorR = Math.floor((Math.random() * 256));
			var colorG = Math.floor((Math.random() * 256));
			var colorB = Math.floor((Math.random() * 256));
			$(":root").get(0).style.setProperty("--first-color-accent", "rgb(" + colorR + "," + colorG + "," + colorB + ")");
			$(":root").get(0).style.setProperty("--first-color-accent-50", "rgba(" + colorR + "," + colorG + "," + colorB + ", 0.5)");
			$(":root").get(0).style.setProperty("--first-color-accent-80", "rgba(" + colorR + "," + colorG + "," + colorB + ", 0.8)");
		}, 750);
	}

	var pathname = document.location.pathname;
	var page = gui_var.pageselector_page;
	var text = gui_var.pageselector_text;

	if (pathname == "/stats.lp") {
		$("#cards-text").text(gui_var.cards_text);
		document.title = "Gateway - "+gui_var.stats_text;
	} else if (pathname == "/cards.lp") {
		$("#cards-text").text(gui_var.stats_text);
		document.title = "Gateway - "+gui_var.cards_text;
	} else if (pathname == "/" ) {
		document.title = "Gateway - "+gui_var.pageselector_othertext;
	}

	$("#switchViewButton").on("click", function () {
		var pathname = document.location.pathname;
		var text = gui_var.pageselector_othertext;
		var view = gui_var.pageselector_text;

		if (pathname == "/stats.lp") {
			page = "cards.lp";
			text = gui_var.stats_text;
			view = gui_var.cards_text;
		} else if (pathname == "/cards.lp") {
			page = "stats.lp";
			text = gui_var.cards_text;
			view = gui_var.stats_text;
		}

		$("#cards-text").text(openMsg);
		$("#refresh-cards").show();
		$("#refresh-cards").css("margin-right", "5px");
		$("#refresh-cards").addClass("fa fa-sync fa-spin");
		modgui.clearKoInterval();
		KoRequest = {};

		var dynamicContainer = document.querySelector(".dynamic-content");
		if (dynamicContainer && window.ko) {
			ko.cleanNode(dynamicContainer);
		}

		$.get(page + "?contentonly=true").done(function (data) {
			$(".dynamic-content").replaceWith(data);
			$("#cards-text").text(text);
			$("#refresh-cards").hide();
			window.history.pushState("gateway", "Gateway - "+view, page);
			document.title = "Gateway - "+view;
			$("#switchViewButton").trigger("switchcard");
		});
	});
	$("#upgradebtn").hover(
		function () {
			$("#upgradebtn").css("color", "white");
		},
		function () {
			$("#upgradebtn").css("color", "orangered");
		}
	);

	if ((gui_var.autoupgradeview != "") && (gui_var.autoupgradeview != "none")) {
		modgui.postAction("autoupgrade_view");
	};

	$(document).on("click", "#direct-upgrade-btn, #upgradebtn", function (e) {
		e.preventDefault();
		modgui.postAction("system_upgrade_gui", 1, null, "/modals/modgui-modal.lp");
	});

	if ( gui_var.gui_animation == "1" ) {
		AOS.init();
	};
});

$(document).ready(function () {
	ko.bindingHandlers.text = {
		init: function (element, valueAccessor) {
			element.textContent = ko.unwrap(valueAccessor()) || "";
		},
		update: function (element, valueAccessor) {
			var value = String(ko.unwrap(valueAccessor()) || "");
			if (element.textContent !== value) {
				element.textContent = value;
				if (gui_var.gui_animation === "1" && !element.classList.contains("hide")) {
					element.classList.remove("data-pulse");
					void element.offsetWidth;
					element.classList.add("data-pulse");
				}
			}
		}
	};
	ko.bindingHandlers.log_text = {
		init: function (element, valueAccessor) {
			element.textContent = ko.unwrap(valueAccessor()) || "";
		},
		update: function (element, valueAccessor) {
			var value = ko.unwrap(valueAccessor()) || "";
			element.textContent = value;
			var container = element.parentElement && element.parentElement.parentElement && element.parentElement.parentElement.parentElement;
			if (container) {
				container.scrollTop = container.scrollHeight;
			}
		}
	};
	ko.bindingHandlers.html = {
		init: function (element, valueAccessor) {
			element.innerHTML = ko.unwrap(valueAccessor()) || "";
		},
		update: function (element, valueAccessor) {
			var value = ko.unwrap(valueAccessor()) || "";
			if (element.innerHTML !== value) {
				element.innerHTML = value;
			}
		}
	};

	document.addEventListener("visibilitychange", function () {
		if (document.hidden) {
			modgui.clearKoInterval();
		} else {
			modgui.restartKoInterval();
		}
	});
});
