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
    # 上游已停用 searxng（pve-epyc 注释该模块：missing regenerated secret），
    # 按用户 2026-10-22 要求跟随停用。
    # ../../nixos/optional-apps/searxng.nix
    # ../../nixos/optional-apps/clawemail.nix
    # 2026-09-11 新增：Lsky Pro 图床（pic.zhyi.xin），官方 Docker 镜像。
    ../../nixos/optional-apps/lsky-pro.nix
    # 2026-09-02 自 rock5c 迁入（warrior 镜像仅有 amd64 变体，aarch64 主机
    # 无法运行；与 clawemail 同一决策，见 690b0d26）。
    ../../nixos/optional-apps/archiveteam.nix

    # 2026-08-31 自 greencloud 迁入：日历同步定时任务（每小时）。脚本按
    # 主机名取 secrets/per-host/radicale-calendar-sync/tencent.yaml；
    # radicale 服务端仍在 greencloud，脚本内目标地址指向其公网入口。
    ../../nixos/optional-cron-jobs/radicale-calendar-sync.nix
  ];

  lantian.hubproxy.enable = true;

  # Lsky Pro 图床（pic.zhyi.xin，官方 Docker 镜像）
  lantian.lskyPro.enable = true;

  # 个人服务门户（nav.zhyi.xin，原生 OIDC 登录，卡片由求值期生成）
  lantian.navdash.enable = true;

  # searx 已随上游停用，uwsgi 的 confinement 依赖（/run/searx、vassal 降权）一并移除。
  # 如需重启：searxng.nix 重新导入后，uwsgi 必须给 chroot 补 /etc/passwd、
  # /etc/group、/etc/nsswitch.conf（vassal 用 immediate-uid/gid 符号名降权）
  # 与 /run/searx（searx-init 的 RuntimeDirectory，socket+settings.yml 都在里面）。

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

  # Serve /ray (v2ray xhttp) with a real certificate so cn-accel clients
  # can verify TLS; the mesh default vhost only carries snakeoil.
  lantian.nginxVhosts."tencent.zhyi.xin".sslCertificate = "lets-encrypt-zhyi.xin";

}
