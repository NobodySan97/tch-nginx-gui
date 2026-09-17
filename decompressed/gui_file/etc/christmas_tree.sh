#!/bin/sh
# Minimal BusyBox-compatible christmas_tree.sh
# Esegue solo 24-25 Dicembre. Il 26 esegue cleanup: kill -> restart_leds -> exit.

today=$(date +%m%d 2>/dev/null || echo "")
case "$today" in
  1224|1225) ;;
  1226)
    sed -i '/christmas_tree/d' /etc/crontabs/root 2>/dev/null || true
    for p in $(ps | grep '[c]hristmas_tree.sh' | awk '{print $1}'); do
      [ "$p" != "$$" ] && kill "$p" 2>/dev/null || true
    done
    sleep 2
    for p in $(ps | grep '[c]hristmas_tree.sh' | awk '{print $1}'); do
      [ "$p" != "$$" ] && kill -9 "$p" 2>/dev/null || true
    done
    sh -c "sleep 1 && /usr/share/transformer/scripts/restart_leds.sh &"
    exit 0
    ;;
  *)
    sed -i '/christmas_tree/d' /etc/crontabs/root 2>/dev/null || true
    exit 0
    ;;
esac

LOCK="/tmp/christmas_tree.pid"
if [ -f "$LOCK" ]; then
  oldpid=$(cat "$LOCK" 2>/dev/null)
  if [ -n "$oldpid" ] && kill -0 "$oldpid" 2>/dev/null; then
    exit 0
  else
    rm -f "$LOCK" 2>/dev/null
  fi
fi
echo $$ > "$LOCK"
trap 'rm -f "$LOCK"; kill 0; exit' INT TERM EXIT

for p in $(ps | grep '[c]hristmas_tree.sh' | awk '{print $1}'); do
  [ "$p" != "$$" ] && { kill "$p" 2>/dev/null || true; }
done

randd(){
	grep -m1 -ao '[1-7]' /dev/urandom | head -n1
}

powerOnOffRandom(){
	while [ 1 ]; do
		rand=$(randd)
		echo 255 > "$1"/brightness
		sleep $(( $rand - 1 ))
		echo 0 > "$1"/brightness
		sleep $(( $rand - 1 ))
	done
}

for filename in /sys/class/leds/*; do
	[ -f "$filename/brightness" ] && ( powerOnOffRandom "$filename" ) &
done

wait