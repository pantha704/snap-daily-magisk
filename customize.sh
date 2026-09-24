# sourced by Magisk installer. SKIPUNZIP unset → zip extracts into $MODPATH.
ui_print "snap-daily installs:"
ui_print "- scripts → /data/adb/snap_daily/ on next boot"
ui_print "- crontab */5 heartbeat; watch.sh fires at 05:00 IST"
ui_print "- this module service.sh starts crond"
ui_print "⊥ Wi-Fi / ADB 5555 / Tailscale loop"
ui_print "⊥ LSPosed / Zygisk hook"
ui_print "! secrets stay yours: pin token chats"
ui_print "! Snapchat group named 🔥 before first run"

# Magisk applies 0755/0644 across the module by default. Boot scripts need the
# exec bit back or they cannot be launched.
set_perm "$MODPATH/service.sh" 0 0 0755
set_perm "$MODPATH/uninstall.sh" 0 0 0755
set_perm "$MODPATH/snap.sh" 0 0 0755
set_perm "$MODPATH/run.sh" 0 0 0755
set_perm "$MODPATH/watch.sh" 0 0 0755
set_perm "$MODPATH/crontabs/root" 0 0 0600
