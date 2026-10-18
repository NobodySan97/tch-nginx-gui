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

finish() {
	status=$?
	trap - EXIT HUP INT TERM
	if [ "$status" -ne 0 ]; then
		printf '\nCommand failed (exit status %s).\n' "$status" >> "$LOG_LOCATION"
	fi
	set_transformer "rpc.system.modgui.executeCommand.state" "Complete"
	exit "$status"
}

trap finish EXIT
trap 'exit 143' TERM
trap 'exit 130' INT
trap 'exit 129' HUP

set_transformer "rpc.system.modgui.executeCommand.state" "Requested"

# Use one file descriptor so stderr cannot overwrite stdout. Keep the final
# state and log until the next command: polling may miss a one-second window.
$1 >"$LOG_LOCATION" 2>&1
exit $?

