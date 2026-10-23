{
  LT,
  inputs,
  ...
}:
{
  imports = [
    ../../nixos/server.nix

    "${inputs.secrets}/nixos-hidden-module/a3f9d2b6c81e7450"

    ./hardware-configuration.nix
    ../../nixos/optional-apps/cliproxyapi.nix
    (inputs.secrets + "/cliproxyapi.nix")
    ../../nixos/optional-apps/grafana.nix
    ../../nixos/optional-apps/hubproxy.nix
    ../../nixos/optional-apps/navdash.nix
    ../../nixos/optional-apps/prometheus
    # ../../nixos/optional-apps/searxng.nix
    # ../../nixos/optional-apps/clawemail.nix
    ../../nixos/optional-apps/lsky-pro.nix
    ../../nixos/optional-apps/archiveteam.nix

    ../../nixos/optional-cron-jobs/auto-mihoyo-bbs
    ../../nixos/optional-cron-jobs/radicale-calendar-sync.nix
    ../../nixos/optional-cron-jobs/skyland-auto-checkin.nix
  ];

  lantian.hubproxy.enable = true;

  lantian.lskyPro.enable = true;

  lantian.navdash.enable = true;

  lantian.nginxVhosts."prometheus.tencent.zhyi.xin" = {
    locations."/" = {
      proxyPass = "http://127.0.0.1:${LT.portStr.Prometheus.Daemon}";
    };
    sslCertificate = "lets-encrypt-tencent.zhyi.xin";
    noIndex.enable = true;
    accessibleBy = "private";
  };

  boot.kernelParams = [ "console=ttyS0,115200" ];

  systemd.network.networks.eth0 = {
    matchConfig.Name = "eth0";

    address = [ "240d:c000:f05f:8900:4678:c7be:842a:0/128" ];
    routes = [
      {
        Destination = "::/0";
        Gateway = "fe80::fcee:6cff:fe22:4ade";
        GatewayOnLink = true;
      }
    ];
    networkConfig = {
      DHCP = "ipv4";
      IPv6AcceptRA = "no";
    };
  };

  lantian.nginxVhosts."tencent.zhyi.xin".sslCertificate = "lets-encrypt-zhyi.xin";

}
