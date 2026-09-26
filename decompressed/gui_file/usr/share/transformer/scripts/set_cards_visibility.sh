#!/bin/sh
# Saves card visibility settings to /etc/config/web
if [ -f /tmp/cards_visibility.tmp ]; then
    while IFS="=" read -r sec val; do
        [ -n "$sec" ] && [ -n "$val" ] && uci set "web.${sec}.hide=${val}"
    done < /tmp/cards_visibility.tmp
    uci commit web
    rm -f /tmp/cards_visibility.tmp
fi
