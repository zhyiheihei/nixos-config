{ lib, LT, ... }:
{
  imports = [
    ../../nixos/server.nix

    ./hardware-configuration.nix
    ../../nixos/optional-apps/dsh-web
    ../../nixos/optional-apps/grafana.nix
    ../../nixos/optional-apps/hubproxy.nix
    ../../nixos/optional-apps/metapi.nix
    ../../nixos/optional-apps/navdash.nix
    ../../nixos/optional-apps/prometheus
    ../../nixos/optional-apps/searxng.nix
  ];

  lantian.hubproxy.enable = true;

  # DSH web UI（dsh.zhyi.xin，Dex OIDC 登录，模型走 UniAPI）
  lantian.dsh-web.enable = true;

  # 个人服务门户（nav.zhyi.xin，原生 OIDC 登录，卡片由求值期生成）
  lantian.navdash.enable = true;

  # searx 的 favicon 缓存（作者布局：/var/cache/searx）由 vassal 进程写入；
  # 实测 vassal 补充组恒为空（uwsgi immediate-uid 不做 initgroups、add-gid
  # 不生效），且 uwsgi 重启会把 CacheDirectory 属主改回 uwsgi——组/属主
  # 方案都会被覆盖。目录只放 favicon 缓存库，私有实例，直接 0777。
  systemd.services.uwsgi.serviceConfig.CacheDirectoryMode = "0777";

  # Read-only Prometheus API for Homepage's prometheusmetric widgets (migrated
  # from greencloud 2026-08-14 with the monitoring stack). Private only: Homepage
  # resolves prometheus.tencent.zhyi.xin to tencent's LTNET address (198.18.0.128).
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
    # Tencent gives the public IPv6 as a static /128; the gateway is the
    # subnet router's link-local (derived from MAC fe:ee:6c:22:4a:de) and
    # no RA default route is advertised (accept_ra stays off).
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

  # cn-accel is used for the v2ray exit; skip mihomo to save memory.
  lantian.mihomo.enable = false;

  # Serve /ray (v2ray xhttp) with a real certificate so cn-accel clients
  # can verify TLS; the mesh default vhost only carries snakeoil.
  lantian.nginxVhosts."tencent.zhyi.xin".sslCertificate = "lets-encrypt-zhyi.xin";

  # Korea has no entry in the shared yggdrasil regionMappings
  # (nixos/common-apps/yggdrasil/default.nix); peer the closest regions
  # instead of editing the public module.
  services.yggdrasil.regions = [
    "japan"
    "singapore"
  ];
}
