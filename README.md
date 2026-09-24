# snap-daily-magisk

Magisk module for [snap-daily](https://github.com/pantha704/snap-daily). Installs the cycle scripts + crontab, starts `crond` at boot.

Tested: rooted OnePlus 7T (HD1901), Magisk 31.0.

No token, no PIN, no chat id in this repo. Secrets stay on the phone.

## Install

1. Magisk app → Modules → Install from storage → pick the zip.
2. Or: `su -c "magisk --install-module snap-daily-v1.1.zip"`
3. Reboot. Magisk stages the module in `/data/adb/modules_update/` and merges it at boot.
4. Add secrets (see below). Then `su -c "SNAP_DRY=1 sh /data/adb/snap_daily/run.sh"` for a dry run, or `su -c "/data/adb/snap_daily/run.sh"` for a real one.

Dry run: `SNAP_DRY=1` walks wake, unlock, overlay kill, launch, popups, shutter, Send To, the fire chip and Select All, screenshots the send sheet, then force-stops Snapchat without tapping Send. It writes neither `state/last_ok` nor `state/pending`, so it cannot eat that day's snap. Use it after install to prove the path on your own phone.

`crond` starter: module `service.sh` is the real one, and it is proven on the test phone (see Verified). A fallback `/data/adb/service.d/10-snap-crond.sh` is optional and only for the first install. Safe order:

1. Flash the module, reboot.
2. Confirm `crond` is up and the scripts in `/data/adb/snap_daily/` have fresh mtimes.
3. Then delete the fallback, if you ever added one.

Both starters check `pidof crond` first, and `snap.sh` holds `state/runlock`, so a second `crond` cannot double-send. Do not delete the fallback before step 2. If the module's boot step has not been observed and the fallback is gone, a reboot leaves the phone with no `crond` and no scheduled snap.

## What it installs

- `snap.sh` `run.sh` `watch.sh` → `/data/adb/snap_daily/`
- crontab → `/data/adb/snap_daily/crontabs/root` (`*/5` heartbeat only, see below)
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

## Popups and recovery

A step is blocked when the next landmark is missing, a sheet covers it, or the same UI appears twice.

Dismiss order: `OK` only for the Play-services title, then a named word (Not now, Skip, No thanks, Maybe later, Close, Cancel, Got it, Later, Deny, Not interested, Dismiss), then the wide unnamed footer pill (width 400–800, height 70–180, cy 2000–2320). Never Send, Send To, the shutter, Select All, Add, or the nav bar.

If a blocker is still there after that: press **Back**, then re-check the page. Back fires only when a blocker is present (named word, Play-services title, or an unnamed wide button with width ≥ 350 and height ≥ 100 at cy ≥ 1600). An idle screen with no blocker is waited on, not backed out of. Max **4** Backs; if the page is still wrong, Snapchat is force-stopped and reopened, max **2** restarts; then the step fails with the on-screen title and queues a retry.

## The schedule, and why no cron hour is used

busybox `crond` on this device matches the crontab **in UTC and ignores `TZ` in its own environment**. Measured 2026-09-24 with `TZ=Asia/Kolkata` in the daemon: `* 5 * * *` fired during UTC hour 5 while `* 10 * * *` stayed silent during IST hour 10. So `0 5 * * *` means **05:00 UTC = 10:30 IST** — that is how the snap went out 5.5 hours late, with the log itself showing `[10:30]` while the filename stamp read `20260924T050001Z`.

The `TZ=` line inside the crontab file sets the **job** environment only; it does not move the schedule clock.

So the crontab carries a 5-minute heartbeat and nothing else — every 5 minutes is every 5 minutes in any zone. `watch.sh` makes the daily decision with an explicit IST comparison:

1. Telegram spool flush
2. `last_ok` is today → clear `pending`, exit
3. `pending` exists → run (a queued pre-send miss always retries)
4. else, if IST time ≥ `DUE_MIN` (default `300` = 05:00 IST) and `state/ran_<IST date>` does not exist → run

`snap.sh` writes `state/ran_<date>` as soon as it takes the run lock, so the IST day is consumed even when the proof text never appears, and a proof-miss cannot loop. Dry runs and the selftest never write it. Stale markers are pruned by the watcher. `SNAP_DUE_MIN` moves the fire time; `SNAP_NOW_MIN` fakes "now" for tests.

Side benefits: a missed tick is harmless (the next one still fires the same IST day), and a phone that was asleep at 05:00 sends as soon as it wakes rather than skipping the day.

## Offline

Only the snap delivery and the Telegram messages need network. The 05:00 fire, the unlock, the taps and the screenshots are all local.

No network at 05:00: the cycle does not tap anything. It writes `state/pending` with `offline` and exits 2, and the `*/5` watcher retries — so the snap goes out as soon as the phone is back online, the same day, not the next day. One deduped `snap daily queued: phone offline` notice is spooled and delivered when the network returns; the retries do not pile up.

Telegram messages that cannot be delivered are written to `state/tgspool/` (max 20, oldest dropped) and flushed by the watcher on its next run. An `exit 2` cycle deliberately does not spool a log per retry, because `state/pending` already records it.

`SNAP_ONLINE_HOSTS` overrides the two-host probe (`api.telegram.org`, `www.snapchat.com`). `SNAP_SKIP_ONLINE_CHECK=1` skips the probe entirely.

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
- `magisk --install-module snap-daily-v1.1.zip` → exit 0, `customize.sh` output printed, files staged in `/data/adb/modules_update/snap-daily/`
- staged `service.sh` `0755`, `crontabs/root` `0600` (`customize.sh` calls `set_perm`; Magisk's own default is `0644`, which would leave `service.sh` non-executable)
- staged `snap.sh` `sha256` equals the live `/data/adb/snap_daily/snap.sh` and the repo copy
- `service.sh` run by hand against a sandbox `BASE`: 4 files copied, `755` on scripts, `700` on `crontabs` + `secrets`, `600` on the crontab, second run idempotent
- `crond` already running → `service.sh` did not start a second one
- `SNAP_SELFTEST=1 sh snap.sh` on the installed copy → `selftest ok`, and it needs no fixture file (it writes its own into `state/` and removes it)
- `SNAP_DRY=1 sh run.sh` on the device → exit 0, log shows `unlocked`, `blocker dismiss: ok`, `recipient fire-select-all`, `dry run — stopping before Send`; the dump at that moment carried `Deselect All Button` (Select All had already been tapped), the fire chip beside All, and `Send` at cx 1013. Neither `last_ok` nor `pending` was written, and Snapchat was force-stopped
- failsafe gates, sandboxed `BASE` with a stub `run.sh`: a held `state/runlock` makes the cycle log `already running` and exit 0; `pending` + not-done-today makes the watcher exec `run.sh`; done-today makes the watcher clear `pending` and not exec; no `pending` → quiet exit 0
- `SNAP_SELFTEST=1` also asserts the blocker gate: a camera screen (shutter plus nav) is **not** a blocker, and a wide unnamed sheet button is
- back rule seen live: `back 1/4 for ready` → `back landed on expected page` → the run continued to `recipient fire-select-all` and stopped at the dry-run point, exit 0
- after wiping `/data/adb/snap_daily` entirely and re-running the module's `service.sh`, the tree comes back with `snap.sh` `sha256` equal to the module's copy, the crontab intact, `secrets/` `0600`, and the same dry run passes
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
