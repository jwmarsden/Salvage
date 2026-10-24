# MacBook10,1 Suspend Fix (NixOS)

How suspend on lid close was made to work on **salvage**, 2026-10-24
(kernel 7.3). The config is in [`nix/power.nix`](nix/power.nix).

## History

On 2026-10-18 (kernel 7.2), suspending froze the machine: it never woke and
had to be forced off with the power button, with nothing in the journal. So
all sleep was switched off and closing the lid on battery shut the machine
down.

## The fixes

| Problem | Fix (all in `power.nix`) |
|---|---|
| The Apple NVMe controller (`106b:2003`, PCI `0000:01:00.0`) doesn't come back from D3cold, which hung resume | udev rule: `d3cold_allowed=0` on that device, so it only goes as far as D3hot |
| The USB controller (`XHC1`) can wake the machine straight back up | `disable-xhc1-wakeup.service` turns it off in `/proc/acpi/wakeup` at boot. That file toggles, so the service only writes while XHC1 is enabled. |
| After deep sleep (S3) the **speakers stay silent**, and only a reboot brings them back | Sleep with **s2idle** instead: `mem_sleep_default=s2idle` |
| Camera | Already handled: `hardware.facetimehd` unloads and reloads the driver around sleep |

### Why s2idle and not deep

Deep S3 itself works with the NVMe and USB fixes: Wi-Fi, keyboard, trackpad
and camera all come back. But the speakers don't. The speaker amplifiers
appear to be set up only by the firmware at power-on (the same path that needs
`StartupMute=00`, see [macbook-audio-fix.md](macbook-audio-fix.md)), and resume
from S3 skips that path. Rebinding the HDA driver after resume
(`snd_hda_intel` unbind/bind) doesn't bring them back. s2idle keeps the
hardware powered, so the speakers survive. Another user of the same driver
found the same thing
([Fedora Discussion](https://discussion.fedoraproject.org/t/no-sound-after-sleep-mode/126867/11)).

The cost is that s2idle uses more battery while asleep than S3. If overnight
drain turns out to be too high, add suspend-then-shutdown after a few hours.

## Behaviour

| Situation | Result |
|---|---|
| Lid closed (battery or charger) | Suspend. The screen locks first (swayidle `before-sleep`). |
| Lid closed with an external display (docked) | Keeps running |
| Suspend key | Suspend |
| Power button, short press | Asks first: `power-menu` (fuzzel) with Cancel first. logind ignores the press (`HandlePowerKey = "ignore"`) and Sway binds `XF86PowerOff`. Nothing happens on the lock or login screen. |
| Power button, held | The firmware forces the machine off |
| Wake | Open the lid, or press a key / click the trackpad with the lid open. Tap the power button, don't hold it. |
| Hibernate | Off: there's no `resume=` device |

## Checking it

```sh
cat /sys/power/mem_sleep                                # [s2idle] deep
cat /sys/bus/pci/devices/0000:01:00.0/d3cold_allowed    # 0
grep XHC1 /proc/acpi/wakeup                             # *disabled
busctl get-property org.freedesktop.login1 /org/freedesktop/login1 \
  org.freedesktop.login1.Manager HandleLidSwitch        # s "suspend"
journalctl -b -k | grep -E 'PM: suspend (entry|exit)'   # entry (s2idle) ... exit
cat /sys/power/suspend_stats/success /sys/power/suspend_stats/fail
```

## Gotchas

- `nixos-rebuild switch` doesn't restart `systemd-logind`. After changing any
  `services.logind.settings`, run `sudo systemctl reload systemd-logind`.
- To test S3 by hand without the config allowing sleep:
  `echo mem | sudo tee /sys/power/state`. This skips the systemd sleep hooks,
  so unload `facetimehd` first.
- If a resume ever freezes again: hold the power button, then check
  `journalctl -b -1`. If that's empty, add `no_console_suspend` to
  `boot.kernelParams`.
