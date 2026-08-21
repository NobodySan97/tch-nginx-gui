--pretranslated: do not change this file

gettext.textdomain('webui-core')

local items = {
    {"logviewer-modal.lp", T"Log Viewer"},
    {"log-connections-modal.lp", T"Connections"},
    {"log-routingtable-modal.lp", T"Routing Table"},
    {"modem-stats-modal.lp", T"Modem Stats Graph"},
    {"usermgr-modal.lp", T"User Manager"},
    {"system-init-modal.lp", T"Init Management"},
    {"system-cron-modal.lp", T"Cron Management"},
}

require("sharedModalTabHelper").createModalTab(items)
