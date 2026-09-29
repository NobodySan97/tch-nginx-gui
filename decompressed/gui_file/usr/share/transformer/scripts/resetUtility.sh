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



copy_preserved_file() { # <file_path> <dest_dir>
	local f="$1"
	local dest="$2"
	local src=""

	# 1. Live active filesystem (highest priority: always current in runtime)
	if [ -f "$f" ] || [ -L "$f" ]; then
		src="$f"
	# 2. Modoverlay upperdir (when dual-bank OBP is mounted)
	elif [ -f "/modoverlay/bank_mod$f" ] || [ -L "/modoverlay/bank_mod$f" ]; then
		src="/modoverlay/bank_mod$f"
	# 3. Saferoot (old root after pivot)
	elif [ -f "/saferoot$f" ] || [ -L "/saferoot$f" ]; then
		src="/saferoot$f"
	elif [ -f "/saferoot/overlay/$running_bank$f" ] || [ -L "/saferoot/overlay/$running_bank$f" ]; then
		src="/saferoot/overlay/$running_bank$f"
	# 4. Direct overlay partition
	elif [ -f "/overlay/$running_bank$f" ] || [ -L "/overlay/$running_bank$f" ]; then
		src="/overlay/$running_bank$f"
	fi

	if [ -n "$src" ]; then
		mkdir -p "$dest$(dirname "$f")"
		cp -dp "$src" "$dest$f" 2>/dev/null
		return 0
	fi
	return 1
}

preserve_root_files() {
	emergencydir=/tmp/rootfile/emergency
	rm -rf /tmp/rootfile /tmp/shadow_file
	mkdir -p "$emergencydir"
	mkdir -p /tmp/shadow_file

	# Essential root binaries, scripts, and preinit mount hooks
	local preserve_list="
		/etc/init.d/rootdevice
		/etc/rc.d/S94rootdevice
		/etc/rc.d/S10rootdevice
		/usr/sbin/random_seed
		/sbin/insmod
		/usr/sbin/mount_modoverlay
		/sbin/mount_root-mod
		/lib/mount_modroot/05_transfer_basefiles
		/etc/init.d/do_migrate_overlay
		/lib/upgrade/platform.sh
		/sbin/sysupgrade
		/usr/bin/sysupgrade-safe
		/usr/bin/rtfd
		/etc/passwd
		/etc/shadow
	"

	for file in $preserve_list; do
		copy_preserved_file "$file" "$emergencydir"
	done

	# Isolate shadow and encrypted password
	if [ -f "$emergencydir/etc/shadow" ]; then
		cp -p "$emergencydir/etc/shadow" /tmp/shadow_file/shadow 2>/dev/null
	elif [ -f "/etc/shadow" ]; then
		cp -p /etc/shadow /tmp/shadow_file/shadow 2>/dev/null
	fi

	local saved_pass="$(uci -q get modgui.var.encrypted_pass)"
	if [ -n "$saved_pass" ]; then
		echo "$saved_pass" > /tmp/shadow_file/encrypted_pass
	fi
}

deploy_root_and_ssh() {
	local target="/overlay/$running_bank"
	emergencydir=/tmp/rootfile/emergency

	# 1. Restore emergency root files
	if [ -d "$emergencydir" ]; then
		cp -drp "$emergencydir"/* "$target"/ 2>/dev/null
	fi

	# 2. Guarantee root login shell in /etc/passwd is ash
	if [ -f "$target/etc/passwd" ]; then
		sed -i 's#/root:.*$#/root:/bin/ash#' "$target/etc/passwd" 2>/dev/null
	elif [ -f "/etc/passwd" ]; then
		mkdir -p "$target/etc"
		cp -p /etc/passwd "$target/etc/passwd" 2>/dev/null
		sed -i 's#/root:.*$#/root:/bin/ash#' "$target/etc/passwd" 2>/dev/null
	fi

	# 3. Restore shadow file and set strict permissions
	if [ -f "/tmp/shadow_file/shadow" ]; then
		mkdir -p "$target/etc"
		cp -p /tmp/shadow_file/shadow "$target/etc/shadow" 2>/dev/null
		chmod 600 "$target/etc/shadow" 2>/dev/null
	fi

	# 4. If encrypted password was in UCI, guarantee it's injected into shadow
	if [ -f "/tmp/shadow_file/encrypted_pass" ] && [ -f "$target/etc/shadow" ]; then
		local pass="$(cat /tmp/shadow_file/encrypted_pass)"
		if [ -n "$pass" ]; then
			sed -i "s|^root:[^:]*:|root:${pass}:|" "$target/etc/shadow" 2>/dev/null
		fi
	fi

	# 5. Fix executable permissions on all critical root and boot binaries
	chmod +x "$target/etc/init.d/rootdevice" 2>/dev/null
	chmod +x "$target/sbin/mount_root-mod" 2>/dev/null
	chmod +x "$target/usr/sbin/mount_modoverlay" 2>/dev/null
	chmod +x "$target/lib/mount_modroot/05_transfer_basefiles" 2>/dev/null
	chmod +x "$target/etc/init.d/do_migrate_overlay" 2>/dev/null
	chmod +x "$target/sbin/sysupgrade" 2>/dev/null
	chmod +x "$target/usr/bin/sysupgrade-safe" 2>/dev/null
	chmod +x "$target/usr/bin/rtfd" 2>/dev/null

	# 6. Ensure rootdevice autostart symlinks in /etc/rc.d
	mkdir -p "$target/etc/rc.d"
	ln -sf ../init.d/rootdevice "$target/etc/rc.d/S94rootdevice" 2>/dev/null
	ln -sf ../init.d/rootdevice "$target/etc/rc.d/S10rootdevice" 2>/dev/null

	# 7. Force Dropbear SSH to be enabled on LAN port 22 with root password auth
	mkdir -p "$target/etc/config"
	cat << 'EOF' > "$target/etc/config/dropbear"
config dropbear 'lan'
	option Port '22'
	option Interface 'lan'
	option enable '1'
	option RootPasswordAuth 'on'
	option PasswordAuth 'on'
	option RootLogin '1'
EOF

	# 8. Create uci-defaults script as secondary safety net at boot
	mkdir -p "$target/etc/uci-defaults"
	cat << 'EOF' > "$target/etc/uci-defaults/99-rootdevice"
[ -x /etc/init.d/rootdevice ] && {
	/etc/init.d/rootdevice enable 2>/dev/null
	/etc/init.d/rootdevice boot 2>/dev/null
}
[ -x /etc/init.d/dropbear ] && {
	/etc/init.d/dropbear enable 2>/dev/null
	/etc/init.d/dropbear restart 2>/dev/null
}
exit 0
EOF
	chmod +x "$target/etc/uci-defaults/99-rootdevice" 2>/dev/null

	# 9. Clean modoverlay if mounted so custom GUI files don't conflict after reset
	if mount | grep -q '/modoverlay/bank_mod'; then
		rm -rf /modoverlay/bank_mod/www 2>/dev/null
		rm -rf /modoverlay/bank_mod/etc/config/modgui* 2>/dev/null
		rm -rf /modoverlay/bank_mod/usr/share/transformer 2>/dev/null
		# Mirror emergency base files into modoverlay as well for double protection
		cp -drp "$emergencydir"/* /modoverlay/bank_mod/ 2>/dev/null
	fi
}

restoreOriginalGui() {
	running_bank="$(cat /proc/banktable/booted 2>/dev/null)"; running_bank="${running_bank:-bank_1}"
	config_tmp=/tmp/config_tmp
	
	echo "Preserving root files..."
	preserve_root_files

	echo "Copying config files to config_tmp dir in RAM..."
	mkdir -p "$config_tmp"
	if [ -d "/etc/config" ]; then
		cp -r /etc/config/* "$config_tmp"/ 2>/dev/null
	elif [ -d "/overlay/$running_bank/etc/config" ]; then
		cp -r /overlay/$running_bank/etc/config/* "$config_tmp"/ 2>/dev/null
	fi
	rm -f "$config_tmp"/modgui* 2>/dev/null
	
	# Delete any changes from running bank
	rm -rf /overlay/$running_bank
	mkdir -p /overlay/$running_bank
	
	# Restore user configs into running bank
	if [ -d "$config_tmp" ]; then
		mkdir -p /overlay/$running_bank/etc/config
		cp -r "$config_tmp"/* /overlay/$running_bank/etc/config/ 2>/dev/null
	fi
	
	# Deploy root and Dropbear SSH
	deploy_root_and_ssh
	
	sync
	reboot
}

restoreOriginalGuiFull() {
	running_bank="$(cat /proc/banktable/booted 2>/dev/null)"; running_bank="${running_bank:-bank_1}"
	
	echo "Preserving root files..."
	preserve_root_files
	
	# Delete any changes from running bank (wiping modded GUI and user configs)
	rm -rf /overlay/$running_bank
	mkdir -p /overlay/$running_bank
	
	# Deploy root and Dropbear SSH
	deploy_root_and_ssh
	
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

	# Guarantee Dropbear is enabled on LAN port 22 even after stock config reset
	cat << 'EOF' > /etc/config/dropbear
config dropbear 'lan'
	option Port '22'
	option Interface 'lan'
	option enable '1'
	option RootPasswordAuth 'on'
	option PasswordAuth 'on'
	option RootLogin '1'
EOF

	# Ensure root shell in /etc/passwd remains /bin/ash
	sed -i 's#/root:.*$#/root:/bin/ash#' /etc/passwd 2>/dev/null

	touch /root/.install_gui # this is needed to trigger GUI full install after reboot
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
		--resetGuiFull)
			restoreOriginalGuiFull
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

