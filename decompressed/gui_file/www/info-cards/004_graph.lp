--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local proxy = require("datamodel")
local ui_helper = require("web.ui_helper")

local  format = string.format

local _if = proxy.get("rpc.network.interface.@wan.ifname")
local _wan = proxy.get("rpc.network.interface.@wan.up")
local interface = (_if and _if[1] and _if[1].value) or nil
local wan = (_wan and _wan[1] and _wan[1].value) or nil

local graph_interface = interface or "br-lan"

if graph_interface:match("wan") then
	local real_interface = proxy.get(format("uci.network.device.@%s.ifname",graph_interface))
	if real_interface and real_interface[1] and real_interface[1].value then
		graph_interface = real_interface[1].value
	end
end

if interface and ( wan == "1" ) then
	local int_rx = format("/sys/class/net/%s/statistics/rx_bytes",graph_interface)
	local int_tx = format("/sys/class/net/%s/statistics/tx_bytes",graph_interface)
	
	local rx_traffic = "0"
	local tx_traffic = "0"
	local file = io.open(int_rx,"r")
	if file then
		rx_traffic = file:read() or "0"
		file:close()
	end
	file = io.open(int_tx,"r")
	if file then
		tx_traffic = file:read() or "0"
		file:close()
	end

  ngx.print('\
\
<div class="infocard" id="graphtab">\
  <div class="smallcard">\
    ');  ngx.print( ui_helper.createCardHeader(T"WAN Traffic", nil, nil, nil, nil) ); ngx.print('\
    <div class="content card_bg" data-bg-text="&#xf1fe;">\
	<div class="divtable">\
	<form class="form-horizontal">\
	<fieldset>');
	
	local html = {}
	html[#html + 1] = '<div id="canvas_container" style="height:400px;margin-right:20px;"><canvas id="InfoWANChart"></canvas>'
	html[#html + 1] = '<div style="float:right;">' .. T"Polling every 10 seconds" .. '</div>'
	html[#html + 1] = '</div>'
	html[#html + 1] = '<div id="rx_traffic_complete" class="hide" data-bind="text: rx_traffic_complete">' .. rx_traffic .. '</div>'
	html[#html + 1] = '<div id="tx_traffic_complete" class="hide" data-bind="text: tx_traffic_complete">' .. tx_traffic .. '</div>'

	ngx.print(html)
ngx.print('\
	  </fieldset>\
	  </form>\
	  </div>\
    </div>\
  </div>\
</div>\
<script>\
function checkGraphWidth() {\
	if ( $(document).width() > 855 ) {\
	$("#canvas_container").width($(document).width()/2-60);\
} else {\
	$("#canvas_container").width($(document).width()-80);}\
}\
checkGraphWidth();\
$(window).on("resize", checkGraphWidth );\
function formatBit(bit,decimals) {\
   if(bit == 0) return "0 bit";\
	var k = 1000,\
    dm = decimals || 2,\
    sizes = ["bits","Kb", "Mb", "Gb", "Tb", "Pb", "Eb", "Zb", "Yb"],\
    i = Math.floor(Math.log(bit) / Math.log(k));\
   return (bit / Math.pow(k, i)) > 0 ? parseFloat((bit / Math.pow(k, i)).toFixed(dm)) + " " + ( i > -1 ? sizes[i] : "bits") : null;\
}\
var TrafficChartOption = {\
		responsive: true,\
		maintainAspectRatio: false,\
		spanGaps: true,\
		plugins: {\
			legend: { display: false },\
			tooltip: {\
				enabled: true,\
				callbacks: {\
					label: function(context) { \
						return formatBit(context.parsed.y !== undefined ? context.parsed.y : context.raw, 2);\
					},\
					title: function() {\
						return "";\
					}\
				}\
			}\
		},\
		scales: {\
			x: { display: false },\
			y: {\
				min: 0,\
				ticks: {\
					callback: function(value) { \
						return formatBit(value, 2); \
					}\
				}\
			}\
		}\
};\
var wan_ctx = document.getElementById("InfoWANChart").getContext("2d");\
var wanRxdatasets = [];\
var wanTxdatasets = [];\
var timelabel = [];\
var InfoWANChart = new Chart(wan_ctx, {\
    type: "line",\
    data: {labels: timelabel,\
	"datasets":[{"data":wanRxdatasets,\
			"pointBackgroundColor": "#90cd8a",\
			"backgroundColor": "#90cd8a50",\
		},\
		{"data":wanTxdatasets,\
			"pointBackgroundColor": "#f58368",\
			"backgroundColor": "#f5836850",\
    }]},\
    options: TrafficChartOption \
});\
var InfoGraphCardRefresh = function(ElementBinding) {\
		var tx_traffic_complete = document.getElementById("tx_traffic_complete");\
		var rx_traffic_complete = document.getElementById("rx_traffic_complete");\
		if (tx_traffic_complete) {\
			var tx_traffic_old = tx_traffic_complete.textContent;\
			var rx_traffic_old = rx_traffic_complete.textContent;\
			var interface = "'); ngx.print(graph_interface); ngx.print('";\
			$.post("/ajax/traffic_graph.lua?interface=" + interface + \
				"&oldrx=" + rx_traffic_old + "&oldtx=" + tx_traffic_old +"&auto_update=true" ,\
				[tch.elementCSRFtoken()], function(data) {\
					var rx_traffic = data.rx_traffic-data.old_rx_traffic;\
					var tx_traffic = data.tx_traffic-data.old_tx_traffic;\
					ElementBinding.rx_traffic_complete(data.rx_traffic);\
					ElementBinding.tx_traffic_complete(data.tx_traffic);\
					var date = new Date();\
					var lastLabel = timelabel.length > 0 ? timelabel[timelabel.length - 1] : null;\
					var old_time = lastLabel ? Date.parse("01 Jan 1970 " + lastLabel + " GMT") : null;\
					timelabel.push(date.getHours()+":"+date.getMinutes()+":"+date.getSeconds());\
					var time = Date.parse("01 Jan 1970 "+timelabel[timelabel.length - 1]+" GMT");\
					var time_diff = (old_time && time-old_time > 0) ? ((time-old_time)/1000) : 1;\
					var rx_val = Number(rx_traffic) || 0;\
					var tx_val = Number(tx_traffic) || 0;\
					wanRxdatasets.push(Math.round((rx_val*8)/time_diff));\
					wanTxdatasets.push(Math.round((tx_val*8)/time_diff));\
					if (wanTxdatasets.length > 60) {\
						wanTxdatasets.shift();\
						wanRxdatasets.shift();\
						timelabel.shift();\
					}\
					InfoWANChart.update();\
			}, "json");\
		};\
	};\
$(document).ready(function () {\
  new modgui.createAjaxUpdateCard("graphtab",null,"InfoGraphCardInterval",10000,InfoGraphCardRefresh);\
})\
</script>\
'); 

end
