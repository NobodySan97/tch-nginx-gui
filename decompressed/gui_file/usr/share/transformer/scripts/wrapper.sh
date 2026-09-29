#!/bin/sh

LOG_LOCATION=/tmp/command_log

############TRANSFORMER UTILITY##################
set_transformer() {
	cmd="local dm = require('datamodel'); dm.set('$1', '$2'); dm.apply()"
	lua -e "$cmd" >/dev/null 2>&1 || true
	if [ "$1" = "rpc.system.modgui.executeCommand.state" ]; then
		if [ "$2" != "Idle" ]; then
			echo -n "$2" > /tmp/executeCommandRes
		else
			rm -f /tmp/executeCommandRes
		fi
	fi
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

