# FaceTime HD webcam on the 12-inch MacBook (MacBook10,1).
#
# The stock facetimehd setup can't see this model's sensor: the public camera
# firmware (S2ISP-01.43) reports "Sensor is null after hNVStorage Validate" and
# streams never deliver a frame. What works (patjak/facetimehd issue #326):
#
#   1. Newer firmware, S2ISP-01.55.00, and the sensor's calibration file
#      (1675_01XX.dat, sensor 0005/9774), both cut out of AppleCamera.sys in
#      Apple's Boot Camp package. Apple's files can't be redistributed, so
#      this builds them locally from Apple's own download.
#   2. Driver support for this model's sensor size and its Apple ACPI
#      power-on (CMPE). Up to driver 0.7.0 that was a patch from
#      github.com/neron82/macbook10-1-facetimehd-linux; driver 0.7.2 (nixpkgs,
#      Nov 2026) has its own, for the 12-inch MacBook8,1, which the patch no
#      longer applies over. Dropped 2026-11-15 to try 0.7.2's: if the camera
#      stops working, port the patch (commit 61a875ff1a0f) to 0.7.2.
#   3. Kernel 7.x dropped strncpy, which the driver uses: strscpy instead.
#
# It shows up as /dev/video0 ("Apple Facetime HD", 640x480) for Snapshot,
# Teams, Chrome etc.
#
# After changing any of this, reboot: a failed start can leave the camera's
# processor wedged until the next power cycle.
{ ... }:
{
  # Driver module, bdc_pci blacklist and unload/reload around suspend.
  hardware.facetimehd.enable = true;

  nixpkgs.overlays = [
    (final: prev: {
      linuxPackages_latest = prev.linuxPackages_latest.extend (kfinal: kprev: {
        facetimehd = kprev.facetimehd.overrideAttrs (o: {
          postPatch = (o.postPatch or "") + ''
            sed -i 's/\bstrncpy(/strscpy(/g' fthd_v4l2.c
          '';
        });
      });

      # Replaces the stock firmware that hardware.facetimehd installs.
      facetimehd-firmware = final.stdenvNoCC.mkDerivation {
        pname = "facetimehd-firmware-bootcamp";
        version = "1.55.00";

        src = final.fetchurl {
          url = "https://swcdn.apple.com/content/downloads/32/09/041-89042-A_XVZ2U8XKG2/06ub1qfep6wv3g8bb68smwt3ac25xyng83/BootCampESD.pkg";
          hash = "sha256-bhIToqirvHgV80IBD06cFKqqsnwghtHT/BpfG0GFm8k=";
        };
        dontUnpack = true;
        dontFixup = true; # firmware blobs: nothing to strip or patch
        nativeBuildInputs = [ final.p7zip final.libarchive final.unrar final.binutils ];

        buildPhase = ''
          runHook preBuild
          7z x -y "$src" >/dev/null
          bsdtar -xf 'Payload~' './Library/Application Support/BootCamp/WindowsSupport.dmg'
          7z e -y './Library/Application Support/BootCamp/WindowsSupport.dmg' \
            'BootCamp/Drivers/Apple/AppleCamera64.exe' >/dev/null
          unrar e -o+ AppleCamera64.exe AppleCamera.sys >/dev/null

          # Offsets and sizes inside this AppleCamera.sys
          carve() { dd status=none bs=1 skip="$1" count="$2" if=AppleCamera.sys of="$3"; }
          carve   86832 1417220 firmware.bin
          carve 1511184   19040 1871_01XX.dat
          carve 1530224   19040 1874_01XX.dat
          carve 1549264   19040 1771_01XX.dat
          carve 1568304   18048 1674_01XX.dat
          carve 1586352   18048 1675_01XX.dat
          carve 1604400   18048 1671_01XX.dat
          carve 1622448   33072 9112_01XX.dat
          carve 1655520   20080 1222_01XX.dat
          carve 1675600   30240 8221_01XX.dat
          carve 1705840   18656 1571_01XX.dat
          carve 1724496   18672 1575_01XX.dat

          # grep -c reads to the end: grep -q would stop early and SIGPIPE strings
          strings firmware.bin | grep -c 'S2ISP-01.55.00' >/dev/null
          # each calibration file starts with its sensor number, e.g. 16 75
          [ "$(head -c 2 1675_01XX.dat | od -A n -t x1 | tr -d ' ')" = 1675 ]
          runHook postBuild
        '';

        installPhase = ''
          runHook preInstall
          install -Dm644 -t "$out/lib/firmware/facetimehd" firmware.bin *_01XX.dat
          runHook postInstall
        '';

        meta = {
          description = "FaceTime HD camera firmware S2ISP-01.55.00 and sensor calibration, from Apple's Boot Camp package";
          license = final.lib.licenses.unfree;
          sourceProvenance = [ final.lib.sourceTypes.binaryFirmware ];
        };
      };
    })
  ];
}
