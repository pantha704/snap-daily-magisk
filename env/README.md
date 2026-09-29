# env — the persistence chain this module leans on

These are copies of the phone-side files that keep the OnePlus 7T reachable, taken
from the live device on 2026-09-29. They are here because they are a single point
of failure and were, for a while, not backed up anywhere.

Nothing here is part of the snap module. `keepalive.sh` (in the module root) is the
piece that re-raises this chain from the crond heartbeat.

| file | lives at | job |
|---|---|---|
| `00-persist.sh` | `/data/adb/service.d/` | Magisk late_start stage → launches the supervisor |
| `00-persist-early.sh` | `/data/adb/post-fs-data.d/` | **second** stage, so a late_start that does not run is not fatal |
| `wadbd.sh` | `/data/adb/service.d/` | sets `service.adb.tcp.port 5555`, restarts adbd |
| `launch.sh` | `/data/adb/persist/` | `nohup setsid run.sh` |
| `run.sh` | `/data/adb/persist/` | supervisor loop every 5 s: wifi, adb 5555, tailscaled, dropbear :8022 |

## tailscaled is not a module

`tailscaled` here is a manual install (`/data/adb/tailscale/bin/tailscaled`, userspace
networking, socket `/data/adb/tailscale/tmp/tailscaled.sock`). It is started only by
`run.sh`. The old `tsd-autostart` module was removed deliberately, so there is no
Magisk module that raises the tunnel — the supervisor is the whole mechanism.

## Why the copies exist

On 2026-09-29 a restart brought Android up without Magisk's boot stage. The
supervisor never started, so the phone had no tunnel, no adb and no ssh, and
nothing on the phone could fix it: every rooted process there is started by that
stage. Read the "Reboot resilience" section of the module README for the evidence.

Losing these files means losing remote access to the phone permanently, so keep the
copies current: pull them off the device after any change.
