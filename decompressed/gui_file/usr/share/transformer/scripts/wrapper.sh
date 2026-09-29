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
	exit_code=$?
	sync
	if [ $exit_code -eq 0 ]; then
		set_transformer "rpc.system.modgui.executeCommand.state" "Complete"
	else
		set_transformer "rpc.system.modgui.executeCommand.state" "Failed"
	fi
	sleep 3
	set_transformer "rpc.system.modgui.executeCommand.state" "Idle"
	rm -f "$LOG_LOCATION"
) &

