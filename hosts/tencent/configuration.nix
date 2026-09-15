{
  LT,
  lib,
  pkgs,
  config,
  ...
}:
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
    ../../nixos/optional-apps/clawemail.nix
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

  # metapi 崩溃循环修复（2026-09-15 巡检）：nixpkgs 默认 nodejs 24.19.0 带上游
  # 回归 nodejs/node#65446（ObjectWrap cleanup hook 回移植缺 registry），
  # better-sqlite3 的 Statement 被 GC 析构即触发断言 ABRT，约每 3.5 分钟崩一次
  # （journal：Assertion failed: (env) != nullptr）。上游 metapi Docker 实际
  # 跑 node22，钉到 nodejs_22，nixpkgs 修复后可撤销。
  # 注意 buildNpmPackage（extendMkDerivation 分层）下 metapi 的 nodejs 参数
  # 只影响运行期 wrapper，原生模块编译头文件走 buildNpmPackage 的
  # topLevelArgs（默认 pkgs.nodejs），必须两处同时覆盖，否则 dlopen ABI 不匹配。
  systemd.services.metapi.script =
    let
      metapiNode22 = pkgs.nur-xddxdd.metapi.override {
        nodejs = pkgs.nodejs_22;
        buildNpmPackage = pkgs.buildNpmPackage.override {
          nodejs = pkgs.nodejs_22;
        };
      };
    in
    lib.mkForce ''
      export AUTH_TOKEN=$(cat ${config.sops.secrets.default-pw.path})
      export PROXY_TOKEN=$(cat ${config.sops.secrets.metapi-admin-key.path})
      exec ${lib.getExe metapiNode22}
    '';

  # DSH web UI（dsh.zhyi.xin，Dex OIDC 登录，模型走 UniAPI）
  lantian.dsh-web.enable = true;

  # Lsky Pro 图床（pic.zhyi.xin，官方 Docker 镜像）
  lantian.lskyPro.enable = true;

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
