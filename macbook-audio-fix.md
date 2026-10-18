# MacBook10,1 Speaker Audio Fix (NixOS)

How the internal speakers were fixed on **salvage** on 2026-10-18.

## The machine

| | |
|---|---|
| Model | MacBook10,1 (12-inch, 2017) |
| Sound chip | Intel HDA controller (PCI `00:1f.3`) + Cirrus Logic **CS4208** codec |
| Codec subsystem ID | `106b:6600` (the kernel log shows `106b:0000`) |
| OS | NixOS unstable, `linuxPackages_latest` (7.2.10 at the time) |
| Sound server | PipeWire 1.6.9 + WirePlumber 0.5.18 |

## Summary

**Symptom:** no sound from the internal speakers. Headphones worked.

**Cause:** the mainline kernel driver for the CS4208 never switches on the
speaker amplifier on the 12-inch MacBook, so the speakers stay silent even
though Linux plays audio to them correctly.

**Fix:** four changes were needed, and the speakers only worked once all four
were in place:

1. A patched kernel driver (`snd-hda-codec-cs420x`), built from
   [leifliddy/macbook12-audio-driver](https://github.com/leifliddy/macbook12-audio-driver).
2. A WirePlumber rule so PipeWire controls speaker volume in software.
3. The hardware **Master** mixer at 100%, unmuted, and saved across reboots.
4. The Mac firmware variable `StartupMute` set to `00`
   (see [issue #65](https://github.com/leifliddy/macbook12-audio-driver/issues/65)).

---

## Diagnosis

Each check below ruled out one part of the audio chain.

1. **The kernel sees the card.** `/proc/asound/cards` lists `HDA Intel PCH`,
   the `/dev/snd/*` nodes exist, and your user has access through ACLs.
2. **The first "Dummy Output" was not a real fault.** PipeWire on NixOS starts
   only when an app first uses audio (socket activation). Running `wpctl status`
   right after login can show no devices simply because PipeWire hasn't started
   yet.
3. **The sink was muted.** Unmuting it did not help.
4. **The headphones work.** That rules out the sound chip and PipeWire.
5. **Audio reaches the codec.** While a test tone played,
   `/proc/asound/card0/pcm0p/sub0/status` showed `RUNNING`, and the codec dump
   showed the stream on the digital converter `0x0a` feeding speaker pin `0x1d`.
   The silence was after the codec, at the speaker amplifier.
6. Research turned up a known Linux limitation: the in-kernel CS4208 driver only
   supports headphones on MacBook8,1, 9,1 and 10,1.
7. After the patched driver was installed, debug logging
   (`echo 'module snd_hda_codec_cs420x +p' > /sys/kernel/debug/dynamic_debug/control`)
   confirmed it detects "playing to speakers" and runs its speaker setup
   `play_a1534`. GPIO and pin state matched what the driver sets. There was
   still no sound.
8. The hardware **Master** control was at **0% and switched off**. With software
   volume on, PipeWire never raises it. Fixing it was not enough on its own.
9. Issue #65 in the driver repo describes this exact silent-but-everything-looks-right
   state on a MacBook10,1. If the firmware's startup chime is muted, the firmware
   never switches on the speaker amp, and the driver can't do it either. This Mac
   had **no `StartupMute` variable at all**. After setting it to `00` and
   rebooting, the speakers worked. (No chime was heard at boot.)

---

## Changes made

### 1. Patched driver: `/etc/nixos/macbook12-audio.nix`

The upstream installer uses DKMS, which doesn't work on NixOS, so the driver is
packaged as a NixOS module instead. It builds the patched codec module against
the running kernel and installs it in `updates/`, which takes priority over the
in-tree module.

```nix
# Speaker support for the 12" MacBook (MacBook9,1 / MacBook10,1, CS4208 codec).
# Builds a patched snd-hda-codec-cs420x from leifliddy/macbook12-audio-driver
# against the running kernel, replacing the in-tree module.
{ config, pkgs, lib, ... }:

let
  kernel = config.boot.kernelPackages.kernel;

  driverSrc = pkgs.fetchFromGitHub {
    owner = "leifliddy";
    repo = "macbook12-audio-driver";
    rev = "4cdfcdbac2db3f300cc45d9679cfd21df6590a8a";
    hash = "sha256-sAa+df5/dYV7yHNvfKiCBExaw0m4G8Bjmjq/Z9WUq0I=";
  };

  macbook12-audio = pkgs.stdenv.mkDerivation {
    pname = "macbook12-audio-driver";
    version = "${kernel.version}-4cdfcdb";

    src = kernel.src;
    nativeBuildInputs = kernel.moduleBuildDependencies;

    # Only the HDA sound tree is needed (kernel >= 6.17 layout).
    unpackPhase = ''
      tar -xf $src --wildcards '*/sound/hda'
      cd linux-*/sound/hda/codecs/cirrus
    '';

    postPatch = ''
      cp ${driverSrc}/patch_cirrus/cs420x.c \
         ${driverSrc}/patch_cirrus/patch_cirrus_a1534_setup.h \
         ${driverSrc}/patch_cirrus/patch_cirrus_a1534_pcm.h .
      cp ${driverSrc}/patch_cirrus/Makefile_cs420x Makefile
      chmod u+w *
      sed -i 's/\.free/.remove/' patch_cirrus_a1534_pcm.h
    '';

    buildPhase = ''
      make -C ${kernel.dev}/lib/modules/${kernel.modDirVersion}/build \
        M=$PWD CONFIG_SND_HDA_CODEC_CS420X=m modules
    '';

    installPhase = ''
      install -D -m 0644 snd-hda-codec-cs420x.ko \
        $out/lib/modules/${kernel.modDirVersion}/updates/snd-hda-codec-cs420x.ko
    '';
  };
in
{
  boot.extraModulePackages = [ macbook12-audio ];

  # The speakers have no hardware volume control; let PipeWire do it in software.
  services.pipewire.wireplumber.extraConfig."51-macbook-cs4208-softvol" = {
    "monitor.alsa.rules" = [{
      matches = [{ "device.name" = "alsa_card.pci-0000_00_1f.3"; }];
      actions.update-props."api.alsa.soft-mixer" = true;
    }];
  };
}
```

**Notes:**
- `unpackPhase` and `postPatch` follow the upstream `prepare.cirrus.driver.sh` for
  kernels 6.17 and later, which use the `sound/hda/codecs/cirrus/` layout. On
  older kernels the upstream script uses `sound/pci/hda/patch_cirrus.c` instead.
- The WirePlumber rule is change 2 from the summary. The speakers have no
  hardware volume control, so without this rule the volume slider does nothing.

### 2. `/etc/nixos/configuration.nix` edits

Added to `imports`:

```nix
      ./macbook12-audio.nix
```

Added above the `services.pipewire` block:

```nix
  security.sudo.wheelNeedsPassword = false;

  # Audio
  security.rtkit.enable = true;
  hardware.alsa.enablePersistence = true; # keep Master at 100% (speakers use soft volume)
```

| Setting | Why |
|---|---|
| `security.rtkit.enable` | Lets PipeWire get realtime scheduling priority. Without it the logs fill with `RTKit error` and audio can crackle under load. It's part of the standard NixOS PipeWire setup. |
| `hardware.alsa.enablePersistence` | Saves and restores ALSA mixer levels across reboots (`/var/lib/alsa/asound.state`). Without it, Master came back at 0% after each boot. |
| `security.sudo.wheelNeedsPassword = false` | Not needed for audio. You asked for it so sudo could run without a password during this session. **Anything running as your user can now become root without asking.** |

Applied with `sudo nixos-rebuild switch`.

### 3. Hardware mixer level

```sh
nix shell nixpkgs#alsa-utils -c amixer -c0 sset Master 100% unmute
sudo alsactl store      # persisted by hardware.alsa.enablePersistence
```

### 4. Mac firmware variable `StartupMute = 00`

```sh
printf '\x07\x00\x00\x00\x00' | sudo tee \
  /sys/firmware/efi/efivars/StartupMute-7c436110-ab2a-4bbb-a880-fe41995c9f82 >/dev/null
```

- The first 4 bytes are the EFI attributes (non-volatile, boot-service and
  runtime access); the last byte is the value, `00`, which enables the startup
  chime.
- This setting is stored in the Mac's firmware memory (NVRAM), so it **survives
  OS reinstalls**.
- Check it:
  `od -An -tx1 /sys/firmware/efi/efivars/StartupMute-7c436110-ab2a-4bbb-a880-fe41995c9f82`
  The last byte should be `00`.

Then **reboot**. The patched driver loads at boot, and the firmware needs a cold
start to switch on the amp.

---

## Checking it still works

```sh
# Patched module is loaded (path should contain /updates/)
modinfo -n snd_hda_codec_cs420x
sudo dmesg | grep 'out-of-tree'          # "snd_hda_codec_cs420x: loading out-of-tree module"

# Firmware variable
od -An -tx1 /sys/firmware/efi/efivars/StartupMute-7c436110-ab2a-4bbb-a880-fe41995c9f82

# Hardware Master should be 100% [on]
nix shell nixpkgs#alsa-utils -c amixer -c0 sget Master

# PipeWire sink: Speakers port active, not muted
wpctl status
pactl list sinks | grep -E 'Mute|Active Port'

# Test tone (Ctrl+C to stop)
nix shell nixpkgs#alsa-utils -c speaker-test -D pipewire -c2 -t sine -f 440
```

## Troubleshooting

| Symptom | Check / fix |
|---|---|
| `wpctl status` shows only "Dummy Output" right after login | PipeWire hasn't started yet. Play something or wait a moment. If it persists: `systemctl --user restart wireplumber` |
| Speakers silent, headphones fine | Run every check in "Checking it still works" above: the module path, Master level and the `StartupMute` byte. |
| Volume slider doesn't change the speaker volume | The WirePlumber soft-mixer rule isn't being applied. `pw-dump \| grep soft-mixer` should show `true`. |
| `nixos-rebuild` fails building `macbook12-audio-driver` after a kernel update | Upstream kernel changes broke the driver source. Update `rev` and `hash` in `macbook12-audio.nix` to a newer upstream commit, or pin `boot.kernelPackages` to a kernel version that still builds. |
| See what the driver is doing | `sudo sh -c "echo 'module snd_hda_codec_cs420x +p' > /sys/kernel/debug/dynamic_debug/control"`, play audio, then `sudo dmesg`. Lines saying `command nid BAD read check` are mostly harmless: the macOS recording came from a MacBook9,1 (SSID `106b:6500`). |
| No sound after suspend/resume | A known upstream issue (#48, #33). Upstream has added a resume fix (#62). If you hit this, check whether the pinned commit includes it. |

## Undoing everything

1. Remove `./macbook12-audio.nix` from `imports`. You can also remove the
   `rtkit`, `enablePersistence` and `wheelNeedsPassword` lines.
2. Run `sudo nixos-rebuild switch`, then reboot.
3. Optionally, restore the original firmware behaviour (no `StartupMute` variable):
   ```sh
   sudo chattr -i /sys/firmware/efi/efivars/StartupMute-7c436110-ab2a-4bbb-a880-fe41995c9f82
   sudo rm /sys/firmware/efi/efivars/StartupMute-7c436110-ab2a-4bbb-a880-fe41995c9f82
   ```
   Doing this will probably silence the speakers again.

## Other files

- `~/macbook12-issue73/` holds an alternative AI-modified driver posted in
  [issue #73](https://github.com/leifliddy/macbook12-audio-driver/issues/73)
  (zip SHA-256 `87f3f40e999e66d75c392037ca7b94ccc1fbb32a4baf9472f465d93f687cff0d`).
  It is **unreviewed and was not used**; it was kept to look at later.

## References

- Driver: https://github.com/leifliddy/macbook12-audio-driver
- Issue #65 (`StartupMute` and the speaker amp): https://github.com/leifliddy/macbook12-audio-driver/issues/65
- Issue #73 (MacBook10,1 silent speakers): https://github.com/leifliddy/macbook12-audio-driver/issues/73
- Kernel bug 203613 (CS4208 speaker on MacBook9,1): https://bugzilla.kernel.org/show_bug.cgi?id=203613
