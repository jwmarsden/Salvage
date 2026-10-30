# salvage

NixOS configuration for **salvage**, a 12-inch MacBook (2017) given a second
life as a Linux laptop. This repo holds everything that defines the machine:
the NixOS and home-manager config, the Sway desktop, local packages and
database stacks, plus write-ups of the hardware fixes this model needs.

## The machine

| | |
|---|---|
| Model | Apple MacBook10,1 (12-inch, 2017), firmware 428.0.0.0.0 |
| CPU | Intel Core i5-7Y54 (Kaby Lake, 2 cores / 4 threads), fanless |
| Memory | 8 GB, plus zram (compressed swap in RAM, 50%) and a disk swap partition |
| Storage | 512 GB APPLE SSD AP0512J (NVMe, soldered, 4K sectors): EFI on `p1`, ext4 root on `p2`, swap on `p3` |
| Display | 12" Retina 2304×1440, run at 2× in Sway |
| Wi-Fi / Bluetooth | Broadcom BCM4350 (`brcmfmac`) |
| Sound | Intel HDA + Cirrus Logic CS4208 (patched driver) |
| Camera | FaceTime HD, 640×480 (patched `facetimehd`) |
| Keyboard / trackpad | Apple SPI (`applespi`), backlit keyboard |
| OS | NixOS unstable (26.11), `linuxPackages_latest` (kernel 7.3) |
| Desktop | Sway (Wayland) with Waybar, ReGreet login, Tokyo Night theme throughout |
| Docked | Dell UP2716D on the left, laptop panel to its right |

## Hardware fixes

Out of the box, much of this Mac doesn't work on Linux. Each fix has its own
write-up:

| Area | Status | Write-up | Config |
|---|---|---|---|
| **Speakers** | Working | [macbook-audio-fix.md](macbook-audio-fix.md) | [`nix/macbook12-audio.nix`](nix/macbook12-audio.nix), EFI var `StartupMute=00` |
| **Camera** | Working (`/dev/video0`) | Header comment of [`nix/facetimehd-macbook10.nix`](nix/facetimehd-macbook10.nix) | Same file |
| **Suspend on lid close** | Working (s2idle) | [macbook-suspend-fix.md](macbook-suspend-fix.md) | [`nix/power.nix`](nix/power.nix) |
| **Flashing folder at power-on** | Fixed by an NVRAM reset (watching) | [macbook-boot-fix.md](macbook-boot-fix.md) | Firmware NVRAM only, nothing in Nix |
| **Silent startup chime** | Working | [macbook-boot-fix.md](macbook-boot-fix.md#after-an-nvram-reset-put-the-sound-variables-back) | EFI vars `SystemAudioVolume=40`, `SystemAudioVolumeDB=e1` |
| **Keyboard backlight** | Working | Below | `brightnessctl` keys in [`sway/config`](sway/config) |
| **Hibernate** | Not set up | | no `resume=` device |

The short version:

- **Speakers:** a patched `snd-hda-codec-cs420x`
  ([leifliddy/macbook12-audio-driver](https://github.com/leifliddy/macbook12-audio-driver))
  built against the running kernel. On top of that: software volume through
  PipeWire, hardware Master held at 100% (`hardware.alsa.enablePersistence`),
  and the EFI variable `StartupMute=00`.
- **Camera:** newer ISP firmware (S2ISP-01.55.00) and the sensor's calibration
  file, both extracted at build time from Apple's Boot Camp download (they
  can't be redistributed). Also a driver patch for this model's sensor and its
  ACPI power-on, and a `strncpy` → `strscpy` fix for kernel 7.x. After
  changing it, reboot: a failed start can leave the camera wedged until the
  next power cycle.
- **Suspend:** the NVMe is kept out of D3cold and USB can't wake the machine.
  It uses s2idle because the speakers don't come back from deep S3.
- **Flashing folder:** caused by stale macOS startup-disk records in NVRAM.
  The fix was setting the startup disk from the firmware (Option →
  EFI Boot → Control+Enter), then an NVRAM reset (Option+Cmd+P+R). **After any
  NVRAM reset, re-create the three sound EFI variables**, or the speakers go
  silent and the chime comes back at full volume.
- **Keyboard backlight:** `systemd-backlight` restores the last saved level at
  boot. If the keyboard comes up dark, set it with
  `brightnessctl --device='spi::kbd_backlight' set 50%` (or the backlight keys)
  and it'll be remembered.

## Repo layout

| Path | What it is |
|---|---|
| [`nix/configuration.nix`](nix/configuration.nix) | Main NixOS config, with home-manager (user `jwm`) inside it |
| [`nix/macbook12-audio.nix`](nix/macbook12-audio.nix) | Speaker driver build and WirePlumber soft-volume rule |
| [`nix/facetimehd-macbook10.nix`](nix/facetimehd-macbook10.nix) | Camera firmware, calibration file and driver patches |
| [`nix/power.nix`](nix/power.nix) | Suspend, lid and wake settings |
| [`nix/boot-splash.nix`](nix/boot-splash.nix) | Quiet boot: hidden boot menu, Tokyo Night Plymouth splash, console palette |
| [`nix/tkmoo.nix`](nix/tkmoo.nix) | Local package: tkMOO-light 0.3.32 (not in nixpkgs) |
| [`sway/config`](sway/config) | Sway config (symlinked from `~/.config/sway/config`) |
| [`waybar/`](waybar/) | Waybar config and style (symlinked from `~/.config/waybar/`) |
| [`walls/`](walls/) | Wallpapers: `stormlight_02.png` for the desktop and the login screen |
| [`docker/t2d-db/`](docker/t2d-db/) | PostGIS + TimescaleDB (Postgres 16) `gis` database for T2D work |
| [`docker/geodb/`](docker/geodb/) | PostGIS + TimescaleDB (Postgres 17) `geo` database for general spatial work |
| [`docker/redis/`](docker/redis/) | Redis 8 for local development (localhost:6379) |
| [`docker/cata/`](docker/cata/) | cata.co development: Postgres 17 + PostGIS (localhost:5433) and Redis 8 (localhost:6380) |
| [`shells/python-shell.nix`](shells/python-shell.nix) | `nix-shell` with Jupyter, pandas, geopandas, shapely, pyproj, matplotlib |
| [`link-configuration.sh`](link-configuration.sh) | Creates the symlinks below on a fresh install |
| [`salvage-config.md`](salvage-config.md) | Older change notes (2026-10-18); this README supersedes them |

### How it's wired

- The repo lives at **`/etc/nix-config`**. **`~/nix-config`** is a symlink to
  it, and it pushes to `github.com/jwmarsden/Salvage` (`main`).
- `/etc/nixos/configuration.nix` is a symlink to `nix/configuration.nix`.
  Imports like `./power.nix` resolve next to the real file, so new modules in
  `nix/` don't need their own link in `/etc/nixos` (the ones for `power.nix`
  and `macbook12-audio.nix` are leftovers and harmless).
- `/etc/nixos/hardware-configuration.nix` is **not** in the repo. It's the
  generated hardware scan (root, `/boot` and swap by UUID, Broadcom Wi-Fi
  module); don't edit it by hand.
- **Edit the files in the repo, never with `sed -i` on `/etc/nixos/*`.**
  `sed -i` replaces a symlink with a plain file.
- home-manager isn't pinned: it tracks `master` to match the unstable channel.

## Everyday use

```sh
nh os switch                     # apply changes (shows progress and a package diff)
sudo nix-channel --update && nh os switch   # update the channel and apply
sudo nixos-rebuild switch        # the same without nh
sudo systemctl reload systemd-logind  # after changing services.logind.settings
```

- **Rollback:** hold **Space** at power-on for the boot menu and pick an older
  generation (the last 10 are kept), or run `sudo nixos-rebuild switch --rollback`.
- **Cleanup:** weekly garbage collection (keeps 14 days) and store
  optimisation, both automatic. Docker prunes unused images weekly.
- **Passwordless sudo** (`wheelNeedsPassword = false`): convenient, but
  anything running as `jwm` can become root.
- **Unfree packages** are allowed (Chrome, Slack, VS Code, JetBrains, Steam…).

## Desktop

Sway, started from the **ReGreet** login screen. ReGreet runs in `cage`
(single-app compositor), uses the desktop wallpaper, the same GTK theme and a
translucent panel. If it ever fails, **Ctrl+Alt+F2** gives a text login. The
keyring unlocks with your login password. The boot is silent: no boot menu, a
Plymouth splash, and **Esc** during the splash shows the boot messages.

**Look:** Tokyo Night everywhere: GTK 3 and 4 (`Tokyonight-Dark`), Qt
(Fusion style with a qt5ct/qt6ct palette), Papirus-Dark icons (indigo), the
foot terminal (85% opaque), fuzzel, mako, swaylock, zathura and
yazi. Fonts are IBM Plex Sans for the interface and VictorMono Nerd Font for
monospace.

**Waybar:**
- **Left:** app launchers, then the workspaces.
- **Centre:** the clock; hover for a calendar.
- **Right:**
  - Volume: click for pavucontrol, right-click to mute. Capped at 100%.
  - NordVPN: click to connect or disconnect, right-click for the app.
  - OneDrive sync status: click for the live log, right-click to restart.
  - Wi-Fi, power profile, temperature, battery and the tray.

**Idle and lock:**
- Locks after 5 minutes idle, and turns the screen off after 10.
- Locks before suspend.
- **Super+Escape** locks straight away.
- `wlsunset` warms the screen colours from sunset to sunrise, for Adelaide.

### Key bindings (Super = ⌘)

| Keys | Action |
|---|---|
| Super+Enter | Terminal (foot) |
| Super+D | App launcher (fuzzel) |
| Super+Shift+G | Games menu |
| Super+C | VS Code |
| Super+Y | yazi file manager (in a terminal) |
| Super+G | lazygit |
| Super+P | Bitwarden picker (rbw): types or copies a login |
| Super+Shift+V | Clipboard history |
| Super+Shift+S | Drag a box and annotate it in Satty, then copy (Ctrl+C) or save (Ctrl+S, to `~/Pictures/Screenshots`) |
| Super+Shift+A | Screenshot the whole screen (saved to `~/Pictures/Screenshots`, copied to the clipboard) |
| Super+Q or Super+Shift+Q, middle-click a title bar | Close window |
| Super+Escape | Lock |
| Power button (short press) | Power menu: Cancel, Lock, Suspend, Restart, Shut down. Holding the button still forces the machine off. |
| Super+F | Fullscreen |
| Super+Shift+Space | Toggle floating |
| Super+R | Resize mode |
| Super+B / Super+V | Split horizontally / vertically |
| Super+S / W / E | Stacking / tabbed / toggle split layout |
| Super+Shift+− / Super+− | Send to / show the scratchpad |
| Super+T / Super+Shift+T | Title bar / thin border |
| Super+Shift+C | Reload Sway |
| Super+Shift+E | Exit Sway |
| Media keys | Volume (capped at 100%), mute, brightness, keyboard backlight, play/pause (also work on the lock screen) |

## What's installed

**Everyday apps**
- **Browsers:** Chrome and Firefox. The Bitwarden extension is installed in
  both by policy.
- **Kindle** (Cloud Reader) and **Audible** (web player): Chrome app windows
  with their own launcher entries and icons.
- **Communication:** Thunderbird (Gmail and Office 365 mail, calendar and
  contacts), Slack, Teams (`teams-for-linux`).
- **Office and documents:** LibreOffice, Obsidian, draw.io.
- **PDFs and images:**
  - zathura (the default PDF viewer) and Okular (forms, annotations, signing)
  - imv (the default image viewer), GIMP
- **Media:** VLC; Libation (Audible library downloads); Snapshot (camera).
- **Files:** Thunar (archive, volume and git plugins, plus custom right-click
  actions: terminal here, VS Code, QGIS, copy path), File Roller with 7-Zip,
  yazi.
- **Passwords:** Bitwarden desktop, `rbw` and `rofi-rbw`, Seahorse (keyring).
- **Torrents:** qBittorrent, bound to the NordVPN interface.
- **MOO:** tkMOO-light (`tkmoo`). For the pop-up editor, turn on Out of Band →
  "Old-style local edit", and on the MOO run `@edit-options +local`.

**Engineering and GIS**
- **QGIS**, GDAL, PROJ, tippecanoe, DuckDB (spatial), `psql` 17, DBeaver.
- **Redis:** Tiny RDM (desktop client) and iredis (a friendlier `redis-cli`).
- **ODA Viewer**: DWG, DGN and IFC files. It's an AppImage in `~/Applications`
  run through `appimage-run` under XWayland, and the viewer for `.ifc` files,
  via a custom `application/x-ifc` file type.

**Development**
- **Editors:** VS Code, IntelliJ IDEA, PyCharm, RustRover, Neovim (the default
  `$EDITOR`, also `vi`/`vim`).
- **PyCharm projects:** `pycharm-amischatter` opens AMISChatter inside its
  `nix develop` shell, so compiled pip wheels work. Add more in
  `pycharmProjects` in `configuration.nix`.
- **Languages:** Python 3, Node.js LTS (with npm and npx), Rust (`rustup`, with `gcc` as the linker), Java.
  `npm install -g` puts packages in `~/.npm-global`, which is on `PATH`, because the Nix store is read-only.
- **Git:** git with LFS, `gh`, and lazygit. GitHub sign-in is `gh auth login`,
  stored in the keyring; `gh` is git's credential helper for github.com.
- **direnv + nix-direnv:** a `.envrc` with `use nix` / `use flake` loads a
  project's shell on `cd`.
- **Containers:** Docker (socket-activated, so not started at boot) with
  `docker compose`, lazydocker, Podman Desktop.
- **Shell:** zsh with syntax highlighting, autosuggestions, history substring
  search and 50,000 shared history lines, plus the oh-my-posh `robbyrussell`
  prompt. Bash is still configured.
- Claude Code, btop, bat, smartmontools, efibootmgr.

**Games** (Super+Shift+G or "Games" in the launcher): Mines, Sudoku, Shattered
Pixel Dungeon, Unciv, OpenTTD, Steam.

## Services

| Service | Notes |
|---|---|
| **Network** | NetworkManager with the `nm-applet` tray icon. DNS through systemd-resolved: Cloudflare, with Google as fallback, using DNS-over-TLS when available. |
| **NordVPN** | Official client. `nordvpn login` once, then the waybar icon (connects to New Zealand) or `nordvpn c` / `nordvpn d`. The firewall's reverse-path check is set to loose. |
| **Bluetooth** | On at boot; pair from the blueman tray icon. |
| **mDNS (Avahi)** | Finds LAN printers and devices; this machine is `salvage.local`. |
| **Printing** | CUPS, driverless IPP Everywhere (e.g. the Brother MFC-L3750CDW). |
| **OneDrive** | abraunegg client, syncing `~/OneDrive`. One-time setup: run `onedrive`, then `systemctl --user start onedrive@onedrive`. |
| **Dropbox** | Maestral, started with Sway. |
| **Power** | thermald and power-profiles-daemon (fanless machine). |
| **Firmware** | fwupd. |
| **Screen sharing** | xdg-desktop-portal-wlr; slurp picks the screen when docked. |
| **Audio** | PipeWire with WirePlumber. The laptop speakers stay the default output when docked, because USB outputs such as the BT600 dongle are ranked lower. |

### Databases (Docker)

The two Postgres stacks use the same host port (5432), so run one at a time.
None of the stacks start at boot: start them when you need them.

```sh
cd ~/nix-config/docker/t2d-db && docker compose up -d   # gis database (T2D)
cd ~/nix-config/docker/geodb  && docker compose up -d   # geo database
cd ~/nix-config/docker/redis  && docker compose up -d   # Redis
cd ~/nix-config/docker/cata   && docker compose up -d   # cata.co Postgres + Redis
docker compose down                                      # stop (data is kept)
```

- **t2d-db** (`gis`) listens on all interfaces, so QGIS on the LAN can reach it
  at `salvage.local:5432`. Its data lives in the external volume
  `timescaledb_ha_data`.
- **geodb** (`geo`) listens on localhost only.
- **redis** listens on `localhost:6379` only, with no password. It keeps its
  data in the `redis-data` volume, with an append-only file. For a prompt, run
  `docker exec -it redis redis-cli`.
- **cata** (for `~/Source/cata.co`) runs `cata-db` (Postgres 17 + PostGIS, user
  and database `cata`) on `localhost:5433` and `cata-redis` on
  `localhost:6380`, so it can run alongside the others. The app's connection
  strings are in `~/Source/cata.co/.env`. Apply the schema with
  `npm run db:migrate` there.
- Passwords are in each folder's `.env`, which is git-ignored. Never commit
  them.

## Outside the repo

These aren't in git, so on a fresh install they need copying or redoing by
hand:

| What | Where |
|---|---|
| Hardware scan | `/etc/nixos/hardware-configuration.nix` |
| ODA Viewer AppImage and icon; Kindle and Audible icons | `~/Applications/` |
| Database passwords | `docker/*/.env`; cata.co's app config in `~/Source/cata.co/.env` |
| Database data | Docker volumes `timescaledb_ha_data`, `geodb-data`, `redis-data`, `cata-db-data`, `cata-redis-data` |
| EFI variables | `StartupMute`, `SystemAudioVolume`, `SystemAudioVolumeDB`, `Boot0080`; see [macbook-boot-fix.md](macbook-boot-fix.md) |
| Sign-ins | `gh auth login`, `nordvpn login`, `onedrive`, Maestral, `rbw login`, Chrome sync, Libation |
| tkMOO worlds and settings | `~/.tkMOO-lite` |
| Alternative audio driver (unreviewed, not used) | `~/macbook12-issue73/` |

## Fresh install, roughly

1. Install NixOS (UEFI, systemd-boot), with hostname `salvage` and user `jwm`.
2. Clone this repo to `/etc/nix-config` and symlink `~/nix-config` to it.
3. Run `link-configuration.sh` (it links `/etc/nixos/*.nix` and the Sway and
   Waybar configs).
4. Run `sudo nixos-rebuild switch`, then reboot. The camera firmware downloads
   Apple's Boot Camp package during the build.
5. Set the EFI variables and the startup disk
   ([macbook-boot-fix.md](macbook-boot-fix.md)), then reboot and check that the
   speakers work.
6. Copy `~/Applications`, recreate the `.env` files and restore the
   databases, then do the sign-ins listed above.
