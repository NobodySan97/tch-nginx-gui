#!/bin/sh

. /etc/init.d/rootdevice

kernel_ver="$(cat /proc/version | awk '{print $3}')"

logecho "Installing specificDGA package..."

move_files_and_clean(){
  for file in $(find "$1"*/ -xdev | cut -d '/' -f4-); do
    if [ -d "$1$file" ] && [ ! -d "/$file" ]; then
      mkdir -p "/$file"
      continue
    fi

    [ ! -d "$1$file" ] && mv "$1$file" "/$file"

  done
  rm -rf "$1"
}

if [ -z "${kernel_ver##3.4*}" ]; then

  move_files_and_clean /tmp/upgrade-pack-specificDGA/

  opkg install /tmp/3.4_ipk/*
  rm -rf /tmp/3.4_ipk

  enable_new_upnp() {
    logecho "Checking UPnP.."
    if [ -f /etc/init.d/miniupnpd ]; then
      if [ "$(uci get -q upnpd.config.enable_upnp)" ]; then
        if [ "$(uci get -q upnpd.config.enable_upnp)" = "1" ]; then
          logecho "Disabling miniupnpd-tch and redirecting to miniupnpd"
          /etc/init.d/miniupnpd-tch stop
          /etc/init.d/miniupnpd-tch disable
          rm /etc/init.d/miniupnpd-tch
          ln -s /etc/init.d/miniupnpd /etc/init.d/miniupnpd-tch
          /etc/init.d/miniupnpd enable
          if [ ! "$(pgrep "miniupnpd")" ]; then
            /etc/init.d/miniupnpd restart
          fi
        fi
      fi
    fi
  }
  enable_new_upnp

  if [ ! -f /etc/config/dlnad ]; then
    touch /etc/config/dlnad
    uci set dlnad.config=dlnad
    uci set dlnad.config.manufacturer_url='http://www.technicolor.com'
    uci set dlnad.config.model_url='http://www.technicolor.com'
    uci set dlnad.config.radioStations_enabled='0'
    uci set dlnad.config.interface='lan'
    uci set dlnad.config.friendly_name='DLNA Modem Share'
    uci commit dlnad
  fi

  #Use custom driver to remove downgrade limitation... thx @Roleo
  logecho "Checking downgrade limitation bit..."
  if [ "$(uci get -q env.rip.board_mnemonic)" = "VBNT-S" ] &&
    [ "$(uci get -q env.var.prod_number)" = "4132" ] &&
    ( [ -f /proc/rip/0123 ] || [ -f /proc/rip/0122 ] ); then
    logecho "Downgrade limitation bit detected... Removing..."
    rmmod keymanager 2>/dev/null
    rmmod ripdrv 2>/dev/null
    mv /lib/modules/3.4.11/ripdrv.ko /lib/modules/3.4.11/ripdrv.ko_back
    mv /tmp/ripdrv.ko /lib/modules/3.4.11/ripdrv.ko
    insmod /lib/modules/3.4.11/ripdrv.ko 2>/dev/null || insmod ripdrv 2>/dev/null
    echo 0123 >/proc/rip/delete # RIP_ID_RESTRICTED_DOWNGR_OPT (0x123)
    echo 0122 >/proc/rip/delete # RIP_ID_RESTRICTED_DOWNGR_TS (0x122)
    rmmod ripdrv 2>/dev/null
    logecho "Restoring original driver"
    rm -f /lib/modules/3.4.11/ripdrv.ko
    mv /lib/modules/3.4.11/ripdrv.ko_back /lib/modules/3.4.11/ripdrv.ko
    insmod /lib/modules/3.4.11/ripdrv.ko 2>/dev/null || insmod ripdrv 2>/dev/null
    insmod /lib/modules/3.4.11/keymanager.ko 2>/dev/null || insmod keymanager 2>/dev/null
  fi
  if [ -f /tmp/ripdrv.ko ]; then
    rm /tmp/ripdrv.ko
  fi

elif [ -z "${kernel_ver##4.1.38*}" ]; then

  # Purge all legacy binaries, shared libraries, and opkg info for 4.1.x
  rm -rf /tmp/upgrade-pack-specificDGA/usr/lib/lib* \
         /tmp/upgrade-pack-specificDGA/usr/sbin/nginx \
         /tmp/upgrade-pack-specificDGA/usr/sbin/miniupnpd \
         /tmp/upgrade-pack-specificDGA/usr/bin/openssl \
         /tmp/upgrade-pack-specificDGA/usr/bin/dlnad \
         /tmp/upgrade-pack-specificDGA/usr/lib/opkg \
         /tmp/upgrade-pack-specificDGA/tmp/ripdrv.ko 2>/dev/null || true
  move_files_and_clean /tmp/upgrade-pack-specificDGA/
  opkg install /tmp/4.1.38_ipk/*
  rm -rf /tmp/4.1.38_ipk

else # modern kernels (19.x/20.x using 4.1.52)

  rm -rf /tmp/upgrade-pack-specificDGA/usr/lib/lib* \
         /tmp/upgrade-pack-specificDGA/usr/sbin/nginx \
         /tmp/upgrade-pack-specificDGA/usr/sbin/miniupnpd \
         /tmp/upgrade-pack-specificDGA/usr/bin/openssl \
         /tmp/upgrade-pack-specificDGA/usr/bin/dlnad \
         /tmp/upgrade-pack-specificDGA/usr/lib/opkg \
         /tmp/upgrade-pack-specificDGA/bin/busybox_telnet \
         /tmp/upgrade-pack-specificDGA/tmp/ripdrv.ko 2>/dev/null || true
  move_files_and_clean /tmp/upgrade-pack-specificDGA/
  echo "No packages to install for kernel: $kernel_ver"

fi

if [ ! -f /etc/config/telnet ]; then
  touch /etc/config/telnet
  uci set telnet.general=telnet
  uci set telnet.general.enable='0'
  uci commit telnet
fi

if [ -f /bin/busybox_telnet ] && [ ! -f /usr/sbin/telnetd ]; then
  ln -s /bin/busybox_telnet /usr/sbin/telnetd
fi

if [ -f /etc/init.d/telnet ] && [ ! -f /etc/init.d/telnetd ]; then
  ln -s /etc/init.d/telnet /etc/init.d/telnetd
fi
