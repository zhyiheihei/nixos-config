{
  pkgs,
  lib,
  LT,
  inputs,
  config,
  ...
}:
let
  py = pkgs.python3.withPackages (p: with p; [ requests ]);
in
{
  sops.secrets.ddns-gcore-env = {
    sopsFile = inputs.secrets + "/lego.yaml";
    key = "lego-env";
  };

  systemd.services.ddns-gcore = {
    serviceConfig = LT.serviceHarden // {
      Type = "oneshot";
      EnvironmentFile = config.sops.secrets.ddns-gcore-env.path;
      Environment = "IP_COMMAND=${lib.getExe' pkgs.iproute2 "ip"}";
      RestrictAddressFamilies = [
        "AF_UNIX"
        "AF_INET"
        "AF_INET6"
        "AF_NETLINK"
      ];
      ExecStart = "${lib.getExe py} ${./ddns_gcore.py}";
      Restart = "no";
    };
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
  };

  systemd.timers.ddns-gcore = {
    wantedBy = [ "timers.target" ];
    partOf = [ "ddns-gcore.service" ];
    timerConfig = {
      OnCalendar = "hourly";
      Persistent = true;
      Unit = "ddns-gcore.service";
    };
  };
}
