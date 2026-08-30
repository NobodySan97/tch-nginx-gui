#!/bin/sh

. /etc/init.d/rootdevice

check_new_dlnad() {
  logecho "Enable DLNAd"
	#This function will check to see which dlna server daemon is installed
	if [ -f /etc/init.d/dlnad ] && [ ! -f /etc/rc.d/S98dlnad ] && [ -f /etc/init.d/minidlna ]; then
		if [ "$(pgrep "minidlna")" ] ; then
			/etc/init.d/minidlna stop
		fi
		/etc/init.d/minidlna disable
		/etc/init.d/dlnad enable
		if [ ! "$(pgrep "dlnad")" ] ; then
			/etc/init.d/dlnad start
		fi
	fi
	if [ -f /rom/usr/bin/dlnad ]; then
		if [ "$(md5sum /rom/usr/bin/dlnad | awk '{print $1}')" !=  "$(md5sum /usr/bin/dlnad | awk '{print $1}')" ]; then
			if [ "$(pgrep "dlnad")" ] ; then
				/etc/init.d/dlnad stop
			fi
			rm /usr/bin/dlnad
			cp /rom/usr/bin/dlnad /usr/bin/dlnad
			cp /rom/etc/init.d/dlnad /etc/init.d/dlnad
			/etc/init.d/dlnad start
		fi
	fi
}

trafficmon_support() {
  logecho "Trafficmon inizialization"
	if [ -d /root/trafficmon ]; then
		killall trafficmon 2>/dev/null
		killall trafficdata 2>/dev/null
		rm -rf /root/trafficmon
	fi

	if grep -q trafficmon /etc/crontabs/root; then
		killall trafficmon 2>/dev/null
		killall trafficdata 2>/dev/null
		sed -i '/trafficmon/d' /etc/crontabs/root
		sed -i '/trafficdata/d' /etc/crontabs/root
	fi

	if [ -f /etc/init.d/trafficmon ] && [ ! -f /etc/rc.d/S99trafficmon ]; then
		/etc/init.d/trafficmon enable
		if [ ! -f /var/run/trafficmon.pid ]; then
			/etc/init.d/trafficmon start
		fi
	fi
	if [ -f /etc/init.d/trafficdata ] && [ ! -f /etc/rc.d/S99trafficdata ]; then
		/etc/init.d/trafficdata enable
		if [ ! -f /var/run/trafficdata.pid ]; then
			/etc/init.d/trafficdata start
		fi
	fi

}

check_aria_dir() {
	if [ -d /etc/config/aria2 ]; then #Fix generation of config
		mv /etc/config/aria2 /etc/aria2
	fi
	if [ "$(pgrep aria2)" ]; then
		killall aria2c
		aria2c --enable-rpc --rpc-listen-all=true --rpc-allow-origin-all --daemon=true --conf-path=/etc/aria2/aria2.conf
	fi
}

telstra_support_check() {
	if [ ! "$(uci get -q modgui.app.telstra_webui)" ]; then
		uci set modgui.app.telstra_webui="0"
	fi
	if [ -f /tmp/telstra_gui.tar.bz2 ]; then
		if [ "$(uci get -q modgui.app.telstra_webui)" = "1" ]; then
			bzcat /tmp/telstra_gui.tar.bz2 | tar -C / -xf -
		fi
		rm /tmp/telstra_gui.tar.bz2
	fi
}

adblock_support() {
	if [ -f /etc/init.d/adblock ]; then
		logecho "Checking Adblock configuration & sources..."
		mkdir -p /tmp/dnsmasq.d
		
		# Ensure modern reliable sources are configured
		if [ ! "$(uci get -q adblock.stevenblack)" ]; then
			uci set adblock.stevenblack=source
			uci set adblock.stevenblack.adb_src='https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts'
			uci set adblock.stevenblack.adb_src_desc='stevenblack unified hosts (ads, malware, social trackers, analytics, telemetry)'
			uci set adblock.stevenblack.adb_src_rset='/^0\.0\.0\.0[[:space:]]+([[:alnum:]_-]+\.)+[[:alpha:]]+([[:space:]]|$)/{print tolower($2)}'
			uci set adblock.stevenblack.enabled='1'
		fi
		if [ ! "$(uci get -q adblock.oisd)" ]; then
			uci set adblock.oisd=source
			uci set adblock.oisd.adb_src='https://small.oisd.nl/'
			uci set adblock.oisd.adb_src_desc='OISD Small - Zero false positive ad and tracking domain list'
			uci set adblock.oisd.adb_src_rset='BEGIN{FS="[[:space:]]+"} !/^#/ && NF {print tolower($1)}'
			uci set adblock.oisd.enabled='0'
		fi
		if [ ! "$(uci get -q adblock.hagezi)" ]; then
			uci set adblock.hagezi=source
			uci set adblock.hagezi.adb_src='https://raw.githubusercontent.com/hagezi/dns-blocklists/main/domains/pro.txt'
			uci set adblock.hagezi.adb_src_desc='Hagezi Multi Pro (Ads, Trackers, Social, OEMs, Telemetry)'
			uci set adblock.hagezi.adb_src_rset='BEGIN{FS="[[:space:]]+"} !/^#/ && NF {print tolower($1)}'
			uci set adblock.hagezi.enabled='0'
		fi

		# Remove dead and obsolete sources
		for dead in hphosts shalla zeus ransomware malwarelist sysctl ut_capitole reg_cn reg_cz reg_de reg_id reg_nl reg_pl reg_ro reg_ru dshield feodo winhelp hagezi_pro; do
			uci -q delete adblock.$dead
		done

		# Ensure fast mode without CPU-hanging awk tld loop
		[ "$(uci get -q adblock.global.adb_tld)" != "0" ] && uci set adblock.global.adb_tld='0'
		uci commit adblock

		# Ensure adblock.sh uses dnsmasq.d address sinkhole
		if [ -f /usr/bin/adblock.sh ]; then
			sed -i 's|adb_dnsdir="${adb_dnsdir:-"/tmp"}"|adb_dnsdir="${adb_dnsdir:-"/tmp/dnsmasq.d"}"|g' /usr/bin/adblock.sh
			sed -i 's|adb_dnsdeny="awk.*|adb_dnsdeny="awk '"'"'{print \\\\"address=/\\\\"\\\\$0\\\\"/0.0.0.0\\\\"}'"'"'"|g' /usr/bin/adblock.sh
			sed -i 's|killall -q -HUP "${adb_dns}"|/etc/init.d/dnsmasq restart|g' /usr/bin/adblock.sh
		fi
	fi
}

#THIS CHECK DEVICE TYPE AND INSTALL SPECIFIC FILE
device_type="$(uci get -q env.var.prod_friendly_name)"

trafficmon_support #support trafficmon
[ -z "${device_type##*DGA413*}" ] && check_new_dlnad #this enable a new dlna deamon introduced with 17.1, the old one is keep
logecho "Move Aria2 dir"
check_aria_dir #Fix config function
logecho "Reinstalling Telstra GUI if needed..."
telstra_support_check #telstra support check
adblock_support #adblock configuration & sources check
