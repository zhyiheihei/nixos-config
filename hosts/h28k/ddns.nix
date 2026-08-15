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
  # Keep the site hostname (site.zhyi.xin) pointed at the dynamic DHCP WAN.
  # Same Gcore token as the home router's ddns-gcore (lego.yaml lego-env).
  # While the board is still staging at home the record follows the home
  # public IP; re-check after relocation.
  sops.secrets.ddns-gcore-env = {
    sopsFile = inputs.secrets + "/lego.yaml";
    key = "lego-env";
  };

  systemd.services.ddns-gcore = {
    serviceConfig = LT.serviceHarden // {
      Type = "oneshot";
      EnvironmentFile = config.sops.secrets.ddns-gcore-env.path;
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
