# salvage: Config Notes

> **Superseded:** these are the original change notes from 2026-10-18. The current
> state of the machine is in [README.md](README.md). In particular, sleep is no longer
> disabled: see [macbook-suspend-fix.md](macbook-suspend-fix.md).

Notes on how **salvage** is set up and why. Add a new section for each change.

## The machine

| | |
|---|---|
| Hostname | `salvage` |
| Hardware | MacBook10,1 (12-inch, 2017), Apple NVMe SSD, Broadcom BCM4350 Wi-Fi |
| OS | NixOS unstable, `boot.kernelPackages = pkgs.linuxPackages_latest` |
| Desktop | Sway (Wayland), started from `tuigreet` via greetd |
| Audio | PipeWire + WirePlumber |
| Config | `/etc/nixos/configuration.nix` plus imported modules (below) |

### Config files

The real files live in the **`~/nix-config`** git repo, under `nix/`. `/etc/nixos/` holds
symlinks to them (except `hardware-configuration.nix`). Edit the repo copies. Don't
use `sed -i` on `/etc/nixos/*`: it replaces the symlink with a plain file (this
happened once, on 2026-10-18, and was fixed).

| File | What it does |
|---|---|
| `/etc/nixos/configuration.nix` | Main config (home-manager is imported here too) |
| `/etc/nixos/hardware-configuration.nix` | Generated hardware scan; don't edit by hand |
| `/etc/nixos/macbook12-audio.nix` | Patched speaker driver + software volume. See [Audio](#audio) |
| `/etc/nixos/power.nix` | All sleep disabled; lid closed on battery shuts down. See [Power and sleep](#power-and-sleep) |

Apply any change with:

```sh
sudo nixos-rebuild switch
```

---

## Audio

*Changed 2026-10-18.* The full write-up is in **`~/macbook-audio-fix.md`**.

In short, the internal speakers needed four things:

1. **Patched speaker driver:** `macbook12-audio.nix` builds `snd-hda-codec-cs420x` from
   [leifliddy/macbook12-audio-driver](https://github.com/leifliddy/macbook12-audio-driver).
2. **Software volume:** a WirePlumber rule, in the same file, makes PipeWire control
   speaker volume in software.
3. **Hardware Master volume:** set to 100% and kept across reboots by
   `hardware.alsa.enablePersistence = true`.
4. **Firmware setting:** the EFI variable `StartupMute` is set to `00`.

`security.rtkit.enable = true` was also added, so PipeWire gets the high
scheduling priority it needs.

---

## Power and sleep

*Changed 2026-10-18.*

### Problem

Standby hangs the machine: after suspending, it never wakes up and has to be
forced off by holding the power button. The freeze happens before anything is
written to disk, so the journal has no record of these suspends. Hibernation
was never set up (no `resume=` on the kernel command line), so it wasn't the cause.

### Fix: `/etc/nixos/power.nix`

```nix
# Sleep is disabled entirely: this MacBook10,1 freezes on suspend/resume and
# needs a hard power-off to recover. Hibernation was never configured either.
{ ... }:

{
  # Refuse every sleep mode, whatever requests it (lid, keys, apps, systemctl).
  systemd.sleep.settings.Sleep = {
    AllowSuspend = "no";
    AllowHibernation = "no";
    AllowHybridSleep = "no";
    AllowSuspendThenHibernate = "no";
  };

  services.logind.settings.Login = {
    # Lid closed: shut down on battery, stay on when on the charger or docked.
    HandleLidSwitch = "poweroff";
    HandleLidSwitchExternalPower = "ignore";
    HandleLidSwitchDocked = "ignore";

    # Sleep / hibernate keys do nothing.
    HandleSuspendKey = "ignore";
    HandleHibernateKey = "ignore";
  };
}
```

It's imported from `configuration.nix` with `./power.nix` in `imports`.

### Behaviour

| Situation | Result |
|---|---|
| Lid closed, on battery | Clean **shutdown**. Unsaved work in open apps is lost. |
| Lid closed, on the charger | Keeps running |
| Lid closed, external display connected | Keeps running |
| Suspend / hibernate key | Nothing |
| `systemctl suspend`, or an app asking to sleep | Refused |

Closing the lid while on the charger and then unplugging does **not** shut it
down. The lid event has already happened by then.

### Gotcha: logind reload

`nixos-rebuild switch` doesn't restart `systemd-logind`, because restarting it
can end your session. After changing any `services.logind.settings`, reload it:

```sh
sudo systemctl reload systemd-logind
```

### Checking it

```sh
# All four should print s "no"
for m in CanSuspend CanHibernate CanHybridSleep CanSuspendThenHibernate; do
  echo "$m: $(busctl call org.freedesktop.login1 /org/freedesktop/login1 org.freedesktop.login1.Manager $m)"
done

# Lid actions
for p in HandleLidSwitch HandleLidSwitchExternalPower HandleLidSwitchDocked; do
  echo "$p: $(busctl get-property org.freedesktop.login1 /org/freedesktop/login1 org.freedesktop.login1.Manager $p)"
done
```

### Undo

1. Remove `./power.nix` from `imports`.
2. Run `sudo nixos-rebuild switch`.
3. Run `sudo systemctl reload systemd-logind`.

### Possible future work

The freeze on resume hasn't been investigated. Things to look at if standby is
ever wanted back:

- **Sleep mode:** the default is `deep` (S3). `s2idle` is the alternative to try:
  add `mem_sleep_default=s2idle` to `boot.kernelParams`.
- **Drivers to suspect:**
  - **Wi-Fi:** `brcmfmac`. The firmware loads with missing board-specific files.
  - **SSD:** the Apple NVMe controller.
  - **Speakers:** the out-of-tree audio driver. There's a known upstream issue
    about audio after resume.
- **Getting logs from a frozen resume:** temporarily set `systemd.sleep.settings.Sleep.AllowSuspend = "yes"`
  and test with `sudo systemctl suspend`. Check `journalctl -b -1` after the forced reboot.
  If it's empty, try `no_console_suspend` in `boot.kernelParams`.

---

## Desktop: Sway, wallpaper and Waybar

*Changed 2026-10-18.*

- **Sway config:** `~/.config/sway/config` is a copy of `/etc/sway/config` with two changes:
  - Wallpaper: `output * bg /home/jwm/nix-config/walls/stormlight_01.png fill`
  - Bar: `bar { swaybar_command waybar }` replaces the default swaybar.
  - Close the focused window: **⌘ + Q** (added) or **⌘ + Shift + Q** (default).
  - Close a window with the mouse: `bindsym --release button2 kill` (middle-click its title bar).
  - Screenshots: **⌘ + Shift + S** (drag to select an area) and **⌘ + Shift + A** (whole screen).
    They run the `screenshot` script defined in `configuration.nix` (it uses grim, slurp and
    wl-clipboard), save to `~/Pictures/Screenshots/` and copy the image to the clipboard.
    Press Esc while selecting to cancel.
- **Waybar:** `waybar` and `pavucontrol` were added to `environment.systemPackages`.
  - Its config is in `~/.config/waybar/config.jsonc` and `style.css`.
  - Left: launchers for Chrome, Obsidian, a terminal (foot), IntelliJ IDEA (`intellij-idea`) and Steam,
    then the workspaces.
  - Centre: the clock (hover for a calendar).
  - Right: volume (click opens pavucontrol, right-click mutes, scroll changes volume),
    Wi-Fi, battery and the system tray.
  - Icons use the FiraCode Nerd Font, which is already installed.
- **To add a launcher:** copy one of the `custom/…` blocks, add its name to
  `modules-left`, then reload with ⌘ + Shift + C.
- These files are in the `~/nix-config` repo (`sway/config`, `waybar/config.jsonc`,
  `waybar/style.css`). `~/.config/sway/` and `~/.config/waybar/` hold symlinks to them,
  created by `link-configuration.sh`.
- Waybar's process is named `.waybar-wrapped` on NixOS, so look for it with
  `pgrep -a waybar`, not `pgrep -x waybar`.

---

## Shell: zsh

*Changed 2026-10-18.* Your login shell is now **zsh** (`users.users.jwm.shell = pkgs.zsh;`
and `programs.zsh.enable = true;` at the system level). It's configured in home-manager
(`home-manager.users.jwm.programs.zsh`):

- **Syntax highlighting:** commands turn green if valid, red if unknown.
- **Autosuggestions:** a grey suggestion from your history appears as you type.
  Press **→** to accept it.
- **History search:** type part of a command, then press **↑/↓** to cycle through
  matching history.
- **History:** 50,000 entries, shared between open terminals, without duplicates.
- **Prompt:** oh-my-posh (`robbyrussell` theme), the same as in bash.
- **Bash** is still installed and configured (`programs.bash.enable`). Type `bash` to use it.

Gotcha: `~/.zshrc` is generated by home-manager (it's a symlink into the Nix store).
Change zsh settings in `configuration.nix`, not in that file.

---

## Other system settings

| Setting | Why |
|---|---|
| `security.sudo.wheelNeedsPassword = false` | Passwordless sudo, added 2026-10-18 for convenience. Anything running as `jwm` can become root without a prompt. |
| `programs.steam.enable = true` | Steam, added 2026-10-18. Also turns on 32-bit graphics libraries for games. |
| `services.fwupd.enable = true` | Firmware updates |
| `nix.gc` weekly, keep 14 days; `auto-optimise-store` | Stops the Nix store growing without limit |
| `boot.loader.systemd-boot.configurationLimit = 10` | Limits the number of boot menu entries |

## Other files in `~`

| Path | What it is |
|---|---|
| `~/macbook-audio-fix.md` | Detailed audio fix write-up |
| `~/macbook12-issue73/` | Alternative audio driver from upstream issue #73. **Unreviewed, not used.** |
