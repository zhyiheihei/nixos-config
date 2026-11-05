{
  LT,
  config,
  ...
}:
{
  services.ncps = {
    enable = true;
    server.addr = "${LT.this.interconnect.IPv4}:${LT.portStr.Ncps}";
    cache = {
      inherit (config.networking) hostName;
      lru.schedule = "53 4 * * *";
      maxSize = "100G";
      signNarinfo = false;
      tempPath = "/var/lib/ncps/tmp";
      upstream = {
        urls = [ "https://cache.nixos.org" ] ++ LT.constants.nix.substituters;
        publicKeys = LT.constants.nix.trusted-public-keys;

        # 上游超时放宽到 5s/10s（ncps 默认 3s/3s）。家庭宽带出境路径抖动很大
        # （实测 cache.zhyi.xin 直连 TTFB 0.6-5.2s、cache.nixos.org 直连
        # 0.45-13.9s），3s 会让还能用的上游被反复判 unhealthy：cache.zhyi.xin
        # 在 2026-11-01 前的 24h 里翻转了 100 次，翻转期间 LAN 客户端拿不到它
        # 的任何内容（一律 404）。放宽后覆盖实测尾部，真死的上游仍由健康检查
        # 摘掉，只是摘除前的等待变长。
        dialerTimeout = "5s";
        responseHeaderTimeout = "10s";
      };
    };
  };

  # Fill the keys required by ensure-service-harden that upstream does not
  # set; ncps itself is already heavily hardened by the upstream module
  systemd.services.ncps.serviceConfig = {
    AmbientCapabilities = "";
    RemoveIPC = true;
    SystemCallErrorNumber = "EPERM";

    # The cache and migration lock must survive the confinement's tmpfs root.
    BindPaths = [
      config.services.ncps.cache.storage.local
      config.services.ncps.cache.tempPath
      "/run/ncps"
    ];
  };

  lantian.harden.ncps = {
    enable = true;
    # OpenTelemetry resolves the service UID even when exporting is disabled.
    passwd = true;
  };

  systemd.services.ncps.serviceConfig.RestartSec = "5s";
}
