{ lib, LT, ... }:
{
  imports = [
    ../../nixos/server.nix

    ./hardware-configuration.nix
    ../../nixos/optional-apps/grafana.nix
    ../../nixos/optional-apps/hubproxy.nix
    ../../nixos/optional-apps/metapi.nix
    ../../nixos/optional-apps/prometheus
    ../../nixos/optional-apps/searxng.nix
  ];

  lantian.hubproxy.enable = true;

  # searx 的 favicon 缓存库默认放 /var/cache/searx（uwsgi 服务的
  # CacheDirectory，属主 uwsgi）；而搜索进程以 searx 用户跑 vassal 且
  # uwsgi 的 immediate-gid 不继承补充组，永远写不进去 → HTML 搜索 500
  # （JSON/RSS 正常）。把缓存库改到 searx 自己拥有的 /run/searx
  # （tmpfs，favicon 缓存重启丢失可接受）。
  services.searx.faviconsSettings.favicons.cache.db_url = "/run/searx/faviconcache.db";

  # Read-only Prometheus API for Homepage's prometheusmetric widgets (migrated
  # from greencloud 2026-08-14 with the monitoring stack). Private only: Homepage
  # resolves prometheus.tencent.zhyi.cc to tencent's LTNET address (198.18.0.128).
  lantian.nginxVhosts."prometheus.tencent.zhyi.cc" = {
    locations."/" = {
      proxyPass = "http://127.0.0.1:${LT.portStr.Prometheus.Daemon}";
    };
    sslCertificate = "lets-encrypt-tencent.zhyi.cc";
    noIndex.enable = true;
    accessibleBy = "private";
  };

  boot.kernelParams = [ "console=ttyS0,115200" ];

  systemd.network.networks.eth0 = {
    matchConfig.Name = "eth0";
    # Tencent gives the public IPv6 as a static /128; the gateway is the
    # subnet router's link-local (derived from MAC fe:ee:6c:22:4a:de) and
    # no RA default route is advertised (accept_ra stays off).
    address = [ "240d:c000:f05f:8900:4678:c7be:842a:0/128" ];
    routes = [
      {
        routeConfig = {
          Destination = "::/0";
          Gateway = "fe80::fcee:6cff:fe22:4ade";
          GatewayOnLink = true;
        };
      }
    ];
    networkConfig = {
      DHCP = "ipv4";
      IPv6AcceptRA = "no";
    };
  };

  # cn-accel is used for the v2ray exit; skip mihomo to save memory.
  lantian.mihomo.enable = false;

  # Serve /ray (v2ray xhttp) with a real certificate so cn-accel clients
  # can verify TLS; the wg-mesh-wstunnel default vhost only carries snakeoil.
  lantian.nginxVhosts."tencent.zhyi.cc".sslCertificate = "lets-encrypt-zhyi.cc";

  # Korea has no entry in the shared yggdrasil regionMappings
  # (nixos/common-apps/yggdrasil/default.nix); peer the closest regions
  # instead of editing the public module.
  services.yggdrasil.regions = [
    "japan"
    "singapore"
  ];
}
