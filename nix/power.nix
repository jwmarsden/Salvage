# Suspend (s2idle) on this MacBook10,1. It used to freeze on resume and need
# a hard power-off; tested working on 2026-10-24 (kernel 7.3) with the two
# fixes below. The camera driver is unloaded and reloaded around sleep by
# hardware.facetimehd (facetimehd-macbook10.nix). Hibernation was never
# configured (no resume= device), so it stays off.
{ pkgs, ... }:

{
  systemd.sleep.settings.Sleep = {
    AllowSuspend = "yes";
    AllowHibernation = "no";
    AllowHybridSleep = "no";
    AllowSuspendThenHibernate = "no";
  };

  # Sleep with s2idle, not deep S3: after S3 the speakers stay silent (the
  # amps seem to be set up only by the firmware at power-on, which S3 resume
  # skips; rebinding the HDA driver doesn't bring them back).
  boot.kernelParams = [ "mem_sleep_default=s2idle" ];

  # The Apple NVMe controller (106b:2003) doesn't come back from D3cold, which
  # hung resume; keep it in D3hot.
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x106b", ATTR{device}=="0x2003", ATTR{d3cold_allowed}="0"
  '';

  # The USB controller (XHC1) can wake the machine straight back up; leave the
  # lid, keyboard and trackpad as wake sources. /proc/acpi/wakeup toggles, so
  # only write it while XHC1 is enabled.
  systemd.services.disable-xhc1-wakeup = {
    description = "Stop the USB controller waking the machine from sleep";
    wantedBy = [ "multi-user.target" ];
    serviceConfig.Type = "oneshot";
    script = ''
      if ${pkgs.gnugrep}/bin/grep -q '^XHC1.*enabled' /proc/acpi/wakeup; then
        echo XHC1 > /proc/acpi/wakeup
      fi
    '';
  };

  # Low battery: shut down cleanly rather than run flat. A dead battery once
  # left the firmware showing the flashing folder on the next power-on
  # (2026-10-29). Hibernation would need a resume device and the NVMe's
  # sleep quirks, so the critical action is a plain power-off.
  services.upower = {
    enable = true;
    percentageLow = 10;
    percentageCritical = 5;
    percentageAction = 3;
    criticalPowerAction = "PowerOff";
  };

  services.logind.settings.Login = {
    # Lid closed: suspend, on battery or the charger; stay on when docked.
    HandleLidSwitch = "suspend";
    HandleLidSwitchExternalPower = "suspend";
    HandleLidSwitchDocked = "ignore";

    # A short press of the power button is easy to hit by accident: ignore
    # it here and let sway ask first (power-menu). Holding it still forces
    # the machine off (firmware).
    HandlePowerKey = "ignore";
    HandleSuspendKey = "suspend";
    HandleHibernateKey = "ignore";
  };
}
