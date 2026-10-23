{
  pkgs,
  ...
}:
{
  systemd.services.ltnet-scripts-sync = {
    description = "Sync private ltnet-scripts repo and push ROA/zones to the rsync primary";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      User = "zhyi";
      ExecStart = "${pkgs.bash}/bin/bash /home/zhyi/Documents/nixos/ltnet-scripts/scripts/sync.sh";
    };
    path = [
      pkgs.git
      pkgs.curl
      pkgs.rsync
      pkgs.openssh

      pkgs.jq
    ];
  };

  systemd.timers.ltnet-scripts-sync = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "hourly";
      RandomizedDelaySec = "5min";
      Unit = "ltnet-scripts-sync.service";
    };
  };
}
