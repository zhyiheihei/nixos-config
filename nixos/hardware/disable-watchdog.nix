{ lib, ... }:
{
  boot.extraModprobeConfig = ''
    blacklist iTCO_wdt
    blacklist iTCO_vendor_support
    blacklist sp5100_tco
  '';
  boot.kernelParams = [
    "nowatchdog"
    "nmi_watchdog=0"
  ];

  systemd.settings.Manager = {
    RebootWatchdogSec = lib.mkForce "0";
    RuntimeWatchdogSec = lib.mkForce "0";
    KExecWatchdogSec = lib.mkForce "0";
  };
}
