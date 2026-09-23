# snap-daily-magisk

Magisk module for [snap-daily](https://github.com/pantha704/snap-daily). Installs the cycle scripts + crontab, starts `crond` at boot.

Tested: rooted OnePlus 7T (HD1901), Magisk 31.0.

No token, no PIN, no chat id in this repo. Secrets stay on the phone.

## Install

1. Magisk app → Modules → Install from storage → pick the zip.
2. Or: `su -c "magisk --install-module snap-daily-v1.zip"`
3. Reboot. Magisk stages the module in `/data/adb/modules_update/` and merges it at boot.
4. Add secrets (see below). Then `su -c "/data/adb/snap_daily/run.sh"` for a manual test run.

⊥ install the old `/data/adb/service.d/10-snap-crond.sh` too. Module `service.sh` owns `crond` now. Two boot hooks → two `crond`.

## What it installs

- `snap.sh` `run.sh` `watch.sh` → `/data/adb/snap_daily/`
- crontab → `/data/adb/snap_daily/crontabs/root` (`0 5 * * *` + `*/5`, `TZ=Asia/Kolkata`)
- `service.sh` at late_start: copy the 4 files, `chmod`, start `crond` if absent

Does not install:

- PIN, bot token, chat id → you create `secrets/` mode 600
- Wi-Fi / ADB 5555 / Tailscale loop → separate supervisor, see snap-daily README
- Snapchat, LSPosed hook, Zygisk lib

## Secrets

```
/data/adb/snap_daily/secrets/pin     # lock PIN, mode 600, only if the screen may be locked
/data/adb/snap_daily/secrets/token   # Telegram bot token
/data/adb/snap_daily/secrets/chats   # one chat id
/data/adb/snap_daily/secrets/to      # optional: one display name. Missing/empty → 🔥 group
```

```
su -c "mkdir -p /data/adb/snap_daily/secrets && chmod 700 /data/adb/snap_daily/secrets"
su -c "printf '%s\n' 'YOUR_TOKEN' > /data/adb/snap_daily/secrets/token && chmod 600 /data/adb/snap_daily/secrets/token"
```

## Snapchat side

Create a Snapchat group named `🔥`, add the people who get the daily snap. Default send = Send To → `🔥` chip beside All → Select All → Send. Change members in Snapchat, not in code.

## Uninstall

Magisk app → remove module. `uninstall.sh` deletes the 3 scripts + crontab. Leaves `secrets/`. Does not kill `crond`.

## Verified

Static, on this repo:

- `module.prop`: `id` matches `^[a-zA-Z][a-zA-Z0-9._-]+$`, `versionCode` int, LF endings
- `META-INF/com/google/android/updater-script` = exactly `#MAGISK`
- no CRLF anywhere
- `sh -n` clean on all 6 scripts
- zip structure has `module.prop` at root

On the device:

- `magisk --install-module` → exit 0, `customize.sh` output printed
- files land in `/data/adb/modules_update/snap-daily/` + `update` marker → applies at next boot
- module listed enabled, no `disable`, no `remove`
- **Magisk's installer applies 0755/0644 to the whole module**, so `service.sh` arrived non-executable. `customize.sh` now calls `set_perm` on the 5 scripts and `crontabs/root`. Re-installed and confirmed: `service.sh` `0755`, `crontabs/root` `0600`
- ran `service.sh` by hand: exit 0, all 4 files copied, `md5sum` matches payload, perms 755 / crontab 600
- `crond` was already up → `service.sh` did not start a second one
- `SNAP_SELFTEST=1 sh snap.sh` on the installed copy → `selftest ok`
- `secrets/` untouched, crontab intact, persist supervisor + `tailscaled` + `adbd` untouched
- legacy `/data/adb/service.d/10-snap-crond.sh` removed before the module took over

Not verified: the post-reboot merge and `service.sh` launch. Magisk applies `modules_update` at boot, and that step needs a reboot to observe. Everything the boot step depends on is checked above.

Not verified: recovery (TWRP) flash. That needs Magisk's own `module_installer.sh` as `META-INF/com/google/android/update-binary`. Not vendored here (Magisk is GPL-3.0, this tree is MIT). Install from the Magisk app.

## License

MIT. `LICENSE`.
