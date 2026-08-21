#!/bin/sh
#
#	 Custom Gui for Technicolor Modem: utility script and modified gui for the Technicolor Modem
#	 								   interface based on OpenWrt
#
#    Copyright (C) 2018  Christian Marangi <ansuelsmth@gmail.com>
#
#    This file is part of Custom Gui for Technicolor Modem.
#    
#    Custom Gui for Technicolor Modem is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#    
#    Custom Gui for Technicolor Modem is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#    
#    You should have received a copy of the GNU General Public License
#    along with Custom Gui for Technicolor Modem.  If not, see <http://www.gnu.org/licenses/>.
#
#

showUsage() {
	echo "Reset Utility: run custom command to perform advanced reset."
	echo "Usage:"
	echo "	--help 		Show help message"
	echo "	--resetGui 	Restore original gui"
	echo "	--removeRoot 	Remove root and wipe overlay bank (factory reset)"
	echo "	--removeConfig 	Reset config. Modded gui is reinstalled"
}



restoreOriginalGui() {
	running_bank="$(cat /proc/banktable/booted 2>/dev/null)"; running_bank="${running_bank:-bank_1}"
	config_tmp=/tmp/config_tmp
	
	#Copying config simulating a firmware upgrade
	echo "Copying config files to config_tmp dir in RAM..."
	mkdir -p /tmp/config_tmp
	mkdir -p /tmp/shadow_file
	[ -d "/overlay/$running_bank/etc/config" ] && cp -r /overlay/$running_bank/etc/config/* $config_tmp/ 2>/dev/null
	[ -f "/overlay/$running_bank/etc/shadow" ] && cp /overlay/$running_bank/etc/shadow /tmp/shadow_file/ 2>/dev/null
	
	#Saving root files
	emergencydir=/tmp/rootfile/emergency
	mkdir -p /tmp/rootfile
	mkdir -p $emergencydir/etc/init.d 
	mkdir -p $emergencydir/etc/rc.d 
	mkdir -p $emergencydir/usr/bin 
	mkdir -p $emergencydir/lib/upgrade 
	mkdir -p $emergencydir/sbin
	[ -f "/overlay/$running_bank/lib/upgrade/platform.sh" ] && cp /overlay/$running_bank/lib/upgrade/platform.sh $emergencydir/lib/upgrade/ 2>/dev/null
	[ -f "/overlay/$running_bank/sbin/sysupgrade" ] && cp /overlay/$running_bank/sbin/sysupgrade $emergencydir/sbin/ 2>/dev/null
	[ -f "/overlay/$running_bank/etc/init.d/rootdevice" ] && cp /overlay/$running_bank/etc/init.d/rootdevice $emergencydir/etc/init.d/ 2>/dev/null
	[ -f "/overlay/$running_bank/usr/bin/rtfd" ] && cp /overlay/$running_bank/usr/bin/rtfd $emergencydir/usr/bin/ 2>/dev/null
	[ -f "/overlay/$running_bank/usr/bin/sysupgrade-safe" ] && cp /overlay/$running_bank/usr/bin/sysupgrade-safe $emergencydir/usr/bin/ 2>/dev/null
	[ -e "/overlay/$running_bank/etc/rc.d/S94rootdevice" ] && cp -d /overlay/$running_bank/etc/rc.d/S94rootdevice $emergencydir/etc/rc.d/ 2>/dev/null
	
	#Delete any change from running bank
	rm -rf /overlay/$running_bank
	mkdir -p /overlay/$running_bank
	
	#Restore config to be converted and preserve in running bank
	if [ -d "$config_tmp" ]; then
		mkdir -p /overlay/homeware_conversion/etc/config
		mkdir -p /overlay/$running_bank/etc/config
		cp -r $config_tmp/* /overlay/homeware_conversion/etc/config/ 2>/dev/null
		cp -r $config_tmp/* /overlay/$running_bank/etc/config/ 2>/dev/null
		[ -f "$config_tmp/modgui" ] && cp $config_tmp/modgui /overlay/homeware_conversion/etc/modgui_old 2>/dev/null
		[ -f "/tmp/shadow_file/shadow" ] && cp /tmp/shadow_file/shadow /overlay/homeware_conversion/etc/ 2>/dev/null
		[ -f "/tmp/shadow_file/shadow" ] && cp /tmp/shadow_file/shadow /overlay/$running_bank/etc/shadow 2>/dev/null
		[ -f "/tmp/shadow_file/shadow" ] && cp /tmp/shadow_file/shadow /overlay/$running_bank/shadow_old 2>/dev/null
	fi
	
	#Root only
	emergencydir=/tmp/rootfile/emergency
	[ -d "$emergencydir" ] && cp -dr $emergencydir/* /overlay/$running_bank/ 2>/dev/null
	sync
	reboot
}

resetConfig() {
	running_bank="$(cat /proc/banktable/booted 2>/dev/null)"; running_bank="${running_bank:-bank_1}"
	[ -d "/overlay/$running_bank/etc/uci-defaults" ] && rm -rf "/overlay/$running_bank/etc/uci-defaults"
	rm -rf /etc/config/*
	cp -r /rom/etc/config/* /etc/config/
	[ "$(pgrep "cwmpd")" ] && /etc/init.d/cwmpd stop
	[ -f /etc/cwmpd.db ] && rm -f /etc/cwmpd.db
	touch /root/.install_gui #this is needed to trigger GUI full install after reboot mainly to reapply all custom edits to stock config files needed by custom GUI
	sync
	reboot
}

resetCwmp() {
	[ "$(pgrep "cwmpd")" ] && /etc/init.d/cwmpd stop
	[ -f /etc/cwmpd.db ] && rm -f /etc/cwmpd.db
	[ "$(uci get -q env.var.provisioning_code)" ] && uci del env.var.provisioning_code && uci commit env
	/etc/init.d/cwmpd start
}

case "$1" in
		--help)
			showUsage
			;;
		--resetCWMP)
			resetCwmp
			;;
		--resetGui)
			restoreOriginalGui
			;;
		--removeRoot)
			/usr/share/transformer/scripts/hardreset.sh
			;;
		--removeConfig)
			resetConfig
			;;
		"")
			echo "resetUtility: provide an option. Use --help to show them." 1>&2
			;;
		*)
			echo "resetUtility: unknown option '$1'" 1>&2
			exit 1
esac

