{
  LT,
  lib,
  config,
  ...
}:
{
  imports = [
    ./alertmanager.nix
    ./blackbox-exporter.nix
    ./periodic-tasks.nix
    ./rules.nix
    ./scrape-configs.nix
  ];

  services.victoriametrics = {
    enable = true;
    listenAddress = "127.0.0.1:${LT.portStr.Prometheus.Daemon}";
    retentionPeriod = "365d";
    extraOptions = [
      "-memory.allowedBytes=256MiB"
      "-vmalert.proxyURL=http://127.0.0.1:${LT.portStr.Prometheus.VMAlert}"
      # Deduplicate overlapping imports without thinning distinct millisecond timestamps.
      "-dedup.minScrapeInterval=1ms"
    ];
  };

  systemd.services.victoriametrics.serviceConfig.RestartSec = lib.mkForce "5s";
  lantian.harden.victoriametrics.enable = true;

  # Retain archived TSDB ownership without changing userborn and restarting MySQL.
  users.groups.prometheus.gid = config.ids.gids.prometheus;
  users.users.prometheus = {
    description = "Prometheus daemon user";
    uid = config.ids.uids.prometheus;
    group = "prometheus";
  };

  lantian.nginxVhosts."prometheus.zhyi.xin" = {
    locations = {
      "/" = {
        enableOAuth = true;
        proxyPass = "http://127.0.0.1:${LT.portStr.Prometheus.Daemon}";
      };
    };

    accessibleBy = "private";
    sslCertificate = "lets-encrypt-zhyi.xin";
    noIndex.enable = true;
  };
}
