--pretranslated: do not change this file

gettext.textdomain('webui-core')

local items = {
    {"tod-modal.lp", T"Access Control"},
    {"tod_dnd-modal.lp", T"DoNotDisturb Control"},
    {"parental-modal.lp", T"Parental Control"},
}

require("sharedModalTabHelper").createModalTab(items)
