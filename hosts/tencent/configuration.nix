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

  # searx 的 favicon 缓存（作者布局：/var/cache/searx，uwsgi 服务
  # CacheDirectory 属主 uwsgi）由 vassal 进程写入；vassal 以 searx 用户
  # 运行且 uwsgi 掉权限时按 /etc/group 做 initgroups。保持作者模块不动：
  # 主机层把 searx 加进 uwsgi 组 + 缓存目录组可写（实测 add-gid 不生效，
  # extraGroups 才能进入进程补充组）。
  users.users.searx.extraGroups = [ "uwsgi" ];
  systemd.services.uwsgi.serviceConfig.CacheDirectoryMode = "0775";

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
