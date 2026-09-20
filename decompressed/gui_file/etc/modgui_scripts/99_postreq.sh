#!/bin/sh

. /etc/init.d/rootdevice

check_gui_tmp() {
	logecho "Cleaning temporary installation files and archives from /tmp..."
	rm -rf /tmp/GUI_dev.tar.bz2 \
	       /tmp/GUI.tar.bz2 \
	       /tmp/gui_file.tar.bz2 \
	       /tmp/base.tar.bz2 \
	       /tmp/3.4_ipk \
	       /tmp/4.1.38_ipk \
	       /tmp/upgrade-pack-* \
	       /tmp/md5check \
	       /tmp/ledfw* \
	       /tmp/web_unlock \
	       /tmp/dosprotect_orig \
	       /total 2>/dev/null || true
}

start_stop_nginx() {
	logecho "Ensuring nginx is running properly..."
	/etc/init.d/nginx restart 2>/dev/null
	sleep 2
	if ! pgrep -f "/usr/sbin/nginx" >/dev/null 2>&1; then
		logecho "Nginx not running, forcing start..."
		/etc/init.d/nginx start 2>/dev/null
		sleep 1
	fi
}

if [ "$(cat /proc/banktable/booted)" = "bank_1" ] && [ ! "$(uci get -q modgui.var.check_obp)" ]; then
	#this set check_obp bit if not present ONLY IN BANK_1, bank_2 value is set based on bank_1 value
	uci set modgui.var.check_obp="1"
fi

logecho "Applying modifications"
uci commit

check_gui_tmp
logecho "Resetting cwmp and watchdog"
/etc/init.d/watchdog-tch start > /dev/null

#This should comunicate the gui that the upgrade has finished.
if [ -f /root/.install_gui ]; then
  logecho "Removing .install_gui flag"
	rm /root/.install_gui
fi
logecho "Process complete, restarting services."

logecho "Restarting transformer..."
/etc/init.d/transformer restart
sleep 1
for i in 1 2 3 4 5; do
	if transformer-cli get uci.env.var.oui >/dev/null 2>&1; then
		break
	fi
	sleep 1
done

#This file is present only in newer build that don't suffer this strange bug
#if [ ! -f /usr/lib/lua/tch/logger.lua ]; then
#	#Wait this command better way to check if transformer is fully initialized
#	transformer-cli get uci.env.var.oui > /dev/null
#	logecho "Restarting transformer a second time cause it's just shit..."
#	/etc/init.d/transformer restart
#fi

logecho "Stopping nginx"
start_stop_nginx
