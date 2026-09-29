#!/system/bin/sh
export PATH=/system/bin:/system/xbin:/product/bin:/data/adb/tailscale/bin
DIR=/data/adb/persist
LOG=$DIR/persist.log
PIDF=$DIR/run.pid
TS_DIR=/data/adb/tailscale
SOCK=$TS_DIR/tmp/tailscaled.sock
DB=$DIR/dropbear
if [ -f "$PIDF" ]; then
  OP=$(cat "$PIDF" 2>/dev/null)
  if [ -n "$OP" ] && [ -d "/proc/$OP" ]; then
    if tr "\0" " " < /proc/$OP/cmdline 2>/dev/null | grep -q persist/run.sh; then
      exit 0
    fi
  fi
fi
echo $$ > "$PIDF"
log() { echo "$(date "+%m-%d %H:%M:%S") $*" >> "$LOG"; }
listening() {
  want=$1
  while read sl loc rem st rest; do
    [ "$st" = "0A" ] || continue
    lp=${loc##*:}
    lp=$(echo "$lp" | tr A-F a-f)
    [ "$lp" = "$want" ] && return 0
  done < /proc/net/tcp
  return 1
}
wifi_up() { ip link show wlan0 2>/dev/null | grep -q "state UP"; }
ensure_wifi() {
  wifi_up && return 0
  svc wifi enable
  log wifi-enable
}
ensure_adbd() {
  cur=$(getprop persist.adb.tcp.port)
  [ "$cur" = "5555" ] || setprop persist.adb.tcp.port 5555
  cur=$(getprop service.adb.tcp.port)
  [ "$cur" = "5555" ] || setprop service.adb.tcp.port 5555
  [ "$(getprop init.svc.adbd)" = "running" ] || { start adbd; log adbd-start; }
}
ensure_tsd() {
  pidof tailscaled >/dev/null 2>&1 && return 0
  mkdir -p "$TS_DIR/run" "$TS_DIR/tmp"
  $TS_DIR/bin/tailscaled -no-logs-no-support -tun=userspace-networking \
    -statedir=$TS_DIR/tmp -state=$TS_DIR/tmp/tailscaled.state \
    -socket=$SOCK -port=41641 \
    > $TS_DIR/run/tailscaled.log 2>&1 &
  log tsd-start
}
ensure_ssh() {
  [ -x "$DB/dropbear" ] || return 0
  listening 1f56 && return 0
  mkdir -p /debug_ramdisk/dropbear
  if [ -f $DB/.ssh/authorized_keys ]; then
    cp $DB/.ssh/authorized_keys /debug_ramdisk/dropbear/authorized_keys
    chmod 600 /debug_ramdisk/dropbear/authorized_keys
  fi
  KEYDIR=/debug_ramdisk/dropbear
  [ -f /system/etc/dropbear/authorized_keys ] && KEYDIR=/system/etc/dropbear
  $DB/dropbear -R -p 8022 -P $DB/dropbear.pid \
    -r $DB/dropbear_ed25519_host_key -s -D $KEYDIR \
    > $DB/dropbear.log 2>&1
  log dropbear-start:$?
}
log boot-loop pid=$$
while true; do
  ensure_wifi
  ensure_adbd
  ensure_tsd
  ensure_ssh
  sleep 5
done
