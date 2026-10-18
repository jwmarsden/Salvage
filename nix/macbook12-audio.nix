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
