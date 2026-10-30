# Quiet, Tokyo Night themed boot: hidden boot menu, silent kernel, a Plymouth
# splash (#1a1b26 background, NixOS logo, spinner) and a matching console
# palette for the tuigreet login.
#
# Hold Space while powering on to get the boot menu (older generations).
# Press Esc during the splash to see boot messages.
{ pkgs, ... }:

let
  # Plymouth's built-in "spinner" theme, recoloured, with the NixOS
  # snowflake in the middle and the spinner below it.
  tokyonightSplash = pkgs.runCommand "plymouth-tokyonight" { } ''
    dir=$out/share/plymouth/themes/tokyonight
    mkdir -p $dir
    cp ${pkgs.plymouth}/share/plymouth/themes/spinner/*.png $dir/
    cp ${pkgs.nixos-icons}/share/icons/hicolor/256x256/apps/nix-snowflake.png $dir/watermark.png
    sed \
      -e "s|^ImageDir=.*|ImageDir=$dir|" \
      -e 's|^Name=.*|Name=Tokyo Night|' \
      -e '/^Name\[/d' \
      -e 's|^Font=.*|Font=Sans 12|' \
      -e 's|^TitleFont=.*|TitleFont=Sans 30|' \
      -e 's|^WatermarkVerticalAlignment=.*|WatermarkVerticalAlignment=.45|' \
      -e 's|^VerticalAlignment=.*|VerticalAlignment=.65|' \
      -e 's|^BackgroundStartColor=.*|BackgroundStartColor=0x1a1b26|' \
      -e 's|^BackgroundEndColor=.*|BackgroundEndColor=0x1a1b26|' \
      -e 's|^ProgressBarBackgroundColor=.*|ProgressBarBackgroundColor=0x414868|' \
      -e 's|^ProgressBarForegroundColor=.*|ProgressBarForegroundColor=0x7aa2f7|' \
      ${pkgs.plymouth}/share/plymouth/themes/spinner/spinner.plymouth \
      > $dir/tokyonight.plymouth
  '';
in
{
  boot.plymouth = {
    enable = true;
    theme = "tokyonight";
    themePackages = [ tokyonightSplash ];
  };

  # Load the Intel graphics driver early so the splash shows straight away
  # at the panel's native resolution.
  boot.initrd.kernelModules = [ "i915" ];

  # Silent boot: only show messages if something goes wrong.
  boot.consoleLogLevel = 3;
  boot.kernelParams = [
    "quiet"
    "splash"
    "udev.log_level=3"
    "rd.udev.log_level=3"
    "systemd.show_status=auto"
  ];

  # Skip the boot menu; hold Space at power-on to show it.
  boot.loader.timeout = 0;

  # Tokyo Night palette for the text console (tuigreet, TTYs).
  # Order: black red green yellow blue magenta cyan white, then bright.
  console.colors = [
    "15161e" "f7768e" "9ece6a" "e0af68" "7aa2f7" "bb9af7" "7dcfff" "a9b1d6"
    "414868" "f7768e" "9ece6a" "e0af68" "7aa2f7" "bb9af7" "7dcfff" "c0caf5"
  ];
}
