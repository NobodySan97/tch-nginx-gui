--pretranslated: do not change this file

gettext.textdomain('webui-core')

local items = {
    {"wanservices-modal.lp", T"Port Forward"},
    {"dyndns-modal.lp", T"DDNS"},
    {"customdns-modal.lp", T"Custom DNS"},
    {"dmz-modal.lp", T"DMZ"},
    {"upnp-modal.lp", T"UPnP"},
    {"wol-modal.lp", T"WoL / WoW"},
}

require("sharedModalTabHelper").createModalTab(items)
