# snap-daily-magisk

Magisk module for [snap-daily](https://github.com/pantha704/snap-daily). Installs the cycle scripts + crontab, starts `crond` at boot.

Tested: rooted OnePlus 7T (HD1901), Magisk 31.0.

No token, no PIN, no chat id in this repo. Secrets stay on the phone.

## Install

1. Magisk app → Modules → Install from storage → pick the zip.
2. Or: `su -c "magisk --install-module snap-daily-v1.zip"`
3. Reboot. Magisk stages the module in `/data/adb/modules_update/` and merges it at boot.
4. Add secrets (see below). Then `su -c "/data/adb/snap_daily/run.sh"` for a manual test run.

`crond` starter: module `service.sh` is the real one, and it is proven on the test phone (see Verified). A fallback `/data/adb/service.d/10-snap-crond.sh` is optional and only for the first install. Safe order:

1. Flash the module, reboot.
2. Confirm `crond` is up and the scripts in `/data/adb/snap_daily/` have fresh mtimes.
3. Then delete the fallback, if you ever added one.

Both starters check `pidof crond` first, and `snap.sh` holds `state/runlock`, so a second `crond` cannot double-send. Do not delete the fallback before step 2. If the module's boot step has not been observed and the fallback is gone, a reboot leaves the phone with no `crond` and no scheduled snap.

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

On the device (rooted OnePlus 7T, Magisk 31.0):

- `module.prop`: `id` matches `^[a-zA-Z][a-zA-Z0-9._-]+$`, `versionCode` int, LF endings
- `META-INF/com/google/android/updater-script` = exactly `#MAGISK`
- `sh -n` clean on all scripts
- zip has `module.prop` at root, no `.git`, no `README.md` / `LICENSE` / `build.sh`
- `magisk --install-module snap-daily-v1.zip` → exit 0, `customize.sh` output printed, files staged in `/data/adb/modules_update/snap-daily/`
- staged `service.sh` `0755`, `crontabs/root` `0600` (`customize.sh` calls `set_perm`; Magisk's own default is `0644`, which would leave `service.sh` non-executable)
- staged `snap.sh` `sha256` equals the live `/data/adb/snap_daily/snap.sh` and the repo copy
- `service.sh` run by hand against a sandbox `BASE`: 4 files copied, `755` on scripts, `700` on `crontabs` + `secrets`, `600` on the crontab, second run idempotent
- `crond` already running → `service.sh` did not start a second one
- `SNAP_SELFTEST=1 sh snap.sh` on the installed copy → `selftest ok`, and it needs no fixture file (it writes its own into `state/` and removes it)
- `secrets/` untouched; persist supervisor, `tailscaled`, and `adbd` untouched

Reboot test, twice, on the test phone:

- boot 1: `/data/adb/modules_update/snap-daily/` merged into `/data/adb/modules/snap-daily/`, `modules_update` gone, no `disable`, no `remove`, `skip_mount` present
- boot 1: `crond` came up, `/data/adb/snap_daily/` scripts rewritten with fresh mtimes by `service.sh`
- boot 2, with `/data/adb/service.d/10-snap-crond.sh` moved out of `service.d` first: `crond` still came up, alone, and the scripts were rewritten again
- exactly one `crond` process after each boot; `crond.log` shows one start per boot
- `secrets/` still `0600`, crontab still `0600`, `SNAP_SELFTEST=1 sh snap.sh` → `selftest ok`
- persist supervisor, `tailscaled`, and `adbd` :5555 all back after each reboot
- the `*/5` watcher ran 37 times across the log with no `state/pending` present, and sent nothing

Not verified: recovery (TWRP) flash. That needs Magisk's own `module_installer.sh` as `META-INF/com/google/android/update-binary`. Not vendored here (Magisk is GPL-3.0, this tree is MIT). Install from the Magisk app.

Leftover on the test phone, not from this module: `/data/adb/modules/disable` exists with a 1970 timestamp. Modules are still mounted (`/system/etc/hosts` matches the Re-Malwack module byte for byte), so it is not disabling anything. Left alone.

## License

MIT. `LICENSE`.
