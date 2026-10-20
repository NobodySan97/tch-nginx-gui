#!/bin/sh
# Saves card visibility settings to /etc/config/web
if [ -f /tmp/cards_visibility.tmp ]; then
    while IFS="=" read -r sec val || [ -n "$sec" ]; do
        if [ -n "$sec" ] && [ -n "$val" ]; then
            uci -q get "web.${sec}" >/dev/null 2>&1 || uci set "web.${sec}=card"
            uci set "web.${sec}.hide=${val}"
            if [ "$val" = "1" ]; then
                uci set "web.${sec}.visible=0"
            else
                uci set "web.${sec}.visible=1"
            fi
        fi
    done < /tmp/cards_visibility.tmp
    uci commit web
    rm -f /tmp/cards_visibility.tmp
fi
