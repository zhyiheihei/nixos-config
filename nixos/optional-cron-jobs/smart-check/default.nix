{
  pkgs,
  lib,
  config,
  ...
}:
{
  systemd.services.smart-check = {
    description = "Check SMART status of storage devices";
    path = [ pkgs.smartmontools ];
    environment = lib.optionalAttrs (config.networking.hostName == "taishanpi") {
      SKIPPED_DEVICES = "/dev/sda";
    };
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${lib.getExe pkgs.python3} ${./check.py}";
      Restart = "no";
    };
    unitConfig = {
      OnFailure = "notify-email@%n.service";
    };
  };

  systemd.timers.smart-check = {
    wantedBy = [ "timers.target" ];
    partOf = [ "smart-check.service" ];
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
      Unit = "smart-check.service";
    };
  };
}
