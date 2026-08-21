--pretranslated: do not change this file

gettext.textdomain('webui-core')

local items = {
    {"device-modal.lp", T"Devices List"},
    {"hostmap-modal.lp", T"Devices Map"},
    {"traffic-monitor.lp", T"Traffic Monitor"},
    {"wifi-nurse-modal.lp", T"WiFi Nurse"},
}

require("sharedModalTabHelper").createModalTab(items)
