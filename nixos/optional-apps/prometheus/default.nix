{
  LT,
  ...
}:
{
  imports = [
    ./alertmanager.nix
    ./blackbox-exporter.nix
    ./periodic-tasks.nix
    ./scrape-configs.nix
    ./storagebox.nix
  ];

  services.prometheus = {
    enable = true;
    enableReload = true;
    port = LT.port.Prometheus.Daemon;
    listenAddress = "127.0.0.1";
    webExternalUrl = "https://prometheus.zhyi.xin";
    stateDir = "prometheus";
    checkConfig = "syntax-only";
    retentionTime = "365d";

    extraFlags = [
      "--storage.tsdb.retention.size=10GB"
    ];
  };

  systemd.services.prometheus.serviceConfig = LT.serviceHarden;

  lantian.nginxVhosts."prometheus.zhyi.xin" = {
    locations = {
      "/" = {
        enableOAuth = true;
        proxyPass = "http://127.0.0.1:${LT.portStr.Prometheus.Daemon}";
      };
    };

    sslCertificate = "lets-encrypt-zhyi.xin";
    noIndex.enable = true;
  };
}
