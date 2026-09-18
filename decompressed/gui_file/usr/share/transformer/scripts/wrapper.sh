#!/bin/sh

LOG_LOCATION=/tmp/command_log

############TRANSFORMER UTILITY##################
set_transformer() {
	cmd="require('datamodel').set('$1','$2')"
	lua -e "$cmd"
}
#################################################

rm -f "$LOG_LOCATION"
set_transformer "rpc.system.modgui.executeCommand.state" "Requested"

(
	eval "$1" >"$LOG_LOCATION" 2>&1
	sync
	set_transformer "rpc.system.modgui.executeCommand.state" "Complete"
	sleep 3
	set_transformer "rpc.system.modgui.executeCommand.state" "Idle"
	rm -f "$LOG_LOCATION"
) &

