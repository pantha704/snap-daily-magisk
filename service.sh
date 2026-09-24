#!/system/bin/sh
# late_start. Official module script. Do not also drop a copy in service.d.
#
# TZ matters twice:
#   - crond evaluates the crontab schedule in ITS OWN timezone, so the daemon
#     must be started with TZ=Asia/Kolkata or "0 5 * * *" means 05:00 UTC
#     (10:30 IST).
#   - the "TZ=" line inside the crontab file only sets the JOB environment; it
#     does not move the schedule clock.
MODDIR=${0%/*}
BASE=/data/adb/snap_daily
TZONE=${SNAP_TZ:-Asia/Kolkata}
export TZ="$TZONE"

mkdir -p "$BASE/secrets" "$BASE/state" "$BASE/runs" "$BASE/crontabs"
cp -f "$MODDIR/snap.sh" "$BASE/snap.sh"
cp -f "$MODDIR/run.sh" "$BASE/run.sh"
cp -f "$MODDIR/watch.sh" "$BASE/watch.sh"
cp -f "$MODDIR/crontabs/root" "$BASE/crontabs/root"
chmod 755 "$BASE/snap.sh" "$BASE/run.sh" "$BASE/watch.sh"
chmod 700 "$BASE/secrets" "$BASE/crontabs"
chmod 600 "$BASE/crontabs/root"

printf 'crond start: utc=%s ist=%s tz=%s\n' \
  "$(date -u '+%F %T')" "$(TZ="$TZONE" date '+%F %T')" "$TZ" \
  > "$BASE/state/crond_started"

# Is OUR crond (the one pointed at our crontab dir) already up?
ours=
for p in $(pidof crond); do
  if tr '\0' ' ' < "/proc/$p/cmdline" 2>/dev/null | grep -q "$BASE/crontabs"; then
    ours=$p
  fi
done

if [ -n "$ours" ]; then
  # It exists, but a daemon started without TZ would fire on UTC. Restart it.
  if ! tr '\0' '\n' < "/proc/$ours/environ" 2>/dev/null | grep -q '^TZ='; then
    kill "$ours" 2>/dev/null
    sleep 1
    ours=
  fi
fi

if [ -z "$ours" ]; then
  TZ="$TZONE" /system/xbin/crond -b -L "$BASE/crond.log" -c "$BASE/crontabs"
fi
