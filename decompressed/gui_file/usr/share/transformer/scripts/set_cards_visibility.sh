#!/bin/sh
# Saves card visibility settings to /etc/config/web
if [ -f /tmp/cards_visibility.tmp ]; then
    while IFS="=" read -r sec val || [ -n "$sec" ]; do
        if [ -n "$sec" ] && [ -n "$val" ]; then
            uci -q get "web.${sec}" >/dev/null 2>&1 || uci set "web.${sec}=card"
            uci set "web.${sec}.hide=${val}"
        fi
    done < /tmp/cards_visibility.tmp
    uci commit web
    rm -f /tmp/cards_visibility.tmp
fi
