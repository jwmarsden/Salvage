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
