# MacBook10,1 Boot Fix: the Flashing Folder (NixOS)

How the intermittent "flashing folder with a question mark" at power-on was
fixed on **salvage**, October 2026.

## Symptom

Some cold starts (not every boot) showed Apple's flashing folder-with-? instead
of starting NixOS. Holding **Option** at power-on and picking **EFI Boot**
always worked, so the disk and boot loader were fine.

## What it wasn't

- **Hardware.** The SSD (APPLE SSD AP0512J) is soldered to the board: there's
  no drive cable to work loose, and `sudo smartctl -a /dev/nvme0` is clean.
- **systemd-boot.** It was never reached. The folder is Apple's firmware saying
  it couldn't find a startup disk.

## Cause

Stale Apple **startup-disk records in NVRAM**, left over from macOS. They
pointed at the macOS partition, which no longer exists (partition 3 is now swap,
with a different GUID). The firmware sometimes trusted those records over the
normal `BootOrder`. The records were:

- `efi-boot-device` and `efi-backup-boot-device*` (Apple GUID
  `7c436110-ab2a-4bbb-a880-fe41995c9f82`)
- `BootFFFF`, Apple's own startup-disk boot entry, pointing at
  `HD(3, GUID ad6a6e48…)\System\Library\CoreServices\boot.efi`

## Fix, in the order it was done

1. **2026-10-21/22:** removed `efi-boot-device` and `efi-backup-boot-device*`.
2. **2026-10-22: set the startup disk from the firmware.** Hold **Option** at
   power-on, select **EFI Boot**, press **Control+Enter**. This firmware
   records it as `Boot0080` (`\EFI\BOOT\BOOTX64.efi`) with `BootOrder` set to
   `0080`. It does *not* create an `efi-boot-device` variable, so check it
   with `efibootmgr`, not by looking in `/sys/firmware/efi/efivars`.
3. **2026-10-23:** the folder came back, so the stale `BootFFFF` was removed
   (`sudo efibootmgr -b FFFF -B`).
4. **2026-10-24:** it came back again, so the NVRAM was reset: shut down,
   press power and **immediately** hold **Option+Cmd+P+R** for about 20
   seconds. It took a couple of attempts: if the keys go down late, nothing is
   reset.
   - Check it worked: afterwards only about 47 variables remain, and the macOS
     leftovers (`fmm-computer-name`, `preferred-networks`, Bluetooth records…)
     are gone.
   - The firmware rebuilt `BootFFFF` by itself, now pointing at
     `\EFI\BOOT\BOOTX64.efi`, the same file as `Boot0080`. That's the right
     outcome.
   - The first boot after the reset showed a small text prompt ("press any key
     to continue, Escape to cancel"). Accepting it went straight to the boot
     menu.

## After an NVRAM reset: put the sound variables back

A reset also wipes three variables this machine needs. Without `StartupMute`
the speakers stay silent ([macbook-audio-fix.md](macbook-audio-fix.md)).
Without the two volume variables, the firmware plays the full-volume startup
chime. Re-create all three (the first 4 bytes are the attributes, then the
value):

```sh
d=/sys/firmware/efi/efivars; g=7c436110-ab2a-4bbb-a880-fe41995c9f82
printf '\x07\x00\x00\x00\x00' | sudo tee $d/StartupMute-$g >/dev/null          # speakers work
printf '\x07\x00\x00\x00\x40' | sudo tee $d/SystemAudioVolume-$g >/dev/null    # silent boot
printf '\x07\x00\x00\x00\xe1' | sudo tee $d/SystemAudioVolumeDB-$g >/dev/null
for v in StartupMute SystemAudioVolume SystemAudioVolumeDB; do
  echo "$v: $(od -An -tx1 $d/$v-$g)"
done
```

Each should print `07 00 00 80 …` with the value last. To change a variable
that already exists, run `sudo chattr -i` on it first.

## Checking the boot entries

```sh
efibootmgr
# Expected: BootCurrent 0080 (or 0000 just after a reset), BootOrder: 0080,
# and BootFFFF (if present) pointing at \EFI\BOOT\BOOTX64.efi
```

The disk uses 4096-byte sectors, so `Boot0080`'s `HD(1,…,0x200,0x40000)` is
correct in 4K blocks. `Boot0009` (written by `bootctl`) uses 512-byte units
and looks wrong, but it isn't in `BootOrder`, so it's harmless.

## If the folder comes back

- **Workaround:** hold **Option** at power-on and pick **EFI Boot**.
- After the NVRAM reset the startup-disk records are clean. If the folder
  still comes back, stale NVRAM isn't the cause, and the next thing to look at
  is the firmware or the EFI partition itself.
