{
  lib,
  pkgs,
  config,
  ...
}:
let
  cfg = config.lantian.clash-verge.ltnetCompat;

  vergeDataDir = "${
    config.users.users.${cfg.user}.home
  }/.local/share/io.github.clash-verge-rev.clash-verge-rev";
  vergeProfilesDir = "${vergeDataDir}/profiles";

  # LTNET / dn42 豁免规则。只保留订阅（ACL4SSR 全量模板）里没有的条目：
  # RFC1918/loopback/CGNAT/链路本地等私网直连订阅已自带，不再重复前置。
  ltnetRules = [
    "DOMAIN-SUFFIX,zhyi.xin,DIRECT"
    "DOMAIN-SUFFIX,zhyi.dn42,DIRECT"
    "PROCESS-NAME,zerotier-one,DIRECT"
    "DST-PORT,9993,DIRECT"
    "IP-CIDR,198.18.0.0/15,DIRECT,no-resolve"
    "IP-CIDR6,fdd8:1938:4e88::/48,DIRECT,no-resolve"
  ];

  scriptRules = lib.concatStringsSep "\n" (map (r: "    \"${r}\",") ltnetRules);

  # Verge 全局 Merge：唯一的实质修改是 DNS 段。在 Verge 增强链中对每个订阅
  # 深合并生效（实测 2.5.2 下 dns 字段存活；tun 段无需覆盖——TUN 设备地址由
  # mihomo 从 fake-ip-range 自动派生，见下）。
  mergeYaml = pkgs.writeText "clash-verge-merge-ltnet.yaml" ''
    # LTNET / dn42 兼容层 —— 本文件由 NixOS 管理（勿在 Verge GUI 中编辑），
    # 修改请改 nixos/optional-apps/clash-verge.nix。部署后重启 Verge 或重新
    # 激活订阅生效；原理与排障见 docs/human/network/clash-verge-ltnet-compat.md。
    dns:
      enable: true
      ipv6: false
      enhanced-mode: fake-ip
      # 默认池 198.18.0.1/16 与 LTNET 198.18.0.0/15 完全重叠：TUN 开启后所有
      # 域名解析被劫持应答为 fake-ip，该地址又撞上主表里 ZeroTier 的 /15 路由
      # 被丢进隧道黑洞，导致整机断网。迁出至 28.0.0.0/8（未被本机任何路由
      # 前缀覆盖；与 FlClash 覆写 28.0.0.1/16 同思路）。TUN 设备地址随池子
      # 派生为 28.0.0.1/30，同步离开 LTNET。
      fake-ip-range: 28.0.0.1/8
      fake-ip-filter:
        - "*.lan"
        - "+.local"
        # 内网域名必须拿真实 LTNET IP：mihomo 出站绑定物理网卡
        # （auto-detect-interface），够不到 LTNET，绝不能让它经手内网连接；
        # 真实 IP 交给内核后由主表路由直走 ZeroTier。
        - "+.zhyi.xin"
        - localhost.ptlogin2.qq.com
      default-nameserver:
        - 223.5.5.5
        - 223.6.6.6
      nameserver:
        - https://120.53.53.53/dns-query
        - https://223.5.5.5/dns-query
      proxy-server-nameserver:
        - https://120.53.53.53/dns-query
        - https://223.5.5.5/dns-query
  '';

  # Verge 全局 Script：规则前置必须走这里——实测 Merge 的 prepend-rules 键
  # 只被 Verge 原样透传进最终配置，mihomo 忽略未知键，规则并不生效。
  scriptJs = pkgs.writeText "clash-verge-script-ltnet.js" ''
    // LTNET / dn42 豁免规则前置 —— 本文件由 NixOS 管理（勿在 Verge GUI 中编辑）。
    function main(config) {
      var ltnetRules = [
    ${scriptRules}
      ];
      config.rules = ltnetRules.concat(config.rules || []);
      return config;
    }
  '';

  owner = {
    inherit (cfg) user;
    group = config.users.users.${cfg.user}.group;
  };
in
{
  # Clash Verge Rev：FlClash 式的图形代理客户端（托盘 + 一键开关 + 订阅）。
  #
  # - serviceMode：跑 clash-verge-service（root systemd 服务，GUI 经 IPC 控制），
  #   TUN 模式依赖它。
  # - tunMode：给 GUI 二进制加 cap_net_admin/raw 的 wrapper，并放开 rp_filter；
  #   无服务时 TUN 也可用 wrapper 自行提权。
  # - 分流规则由订阅下发。greencloud sublinkpro 的 /c/ 统一订阅实际下发
  #   ACL4SSR 全量模板（不含 LTNET/ZeroTier 豁免），仓库内的
  #   sublinkpro/clash.yaml 是本网络设计的权威订阅模板；两者都不感知
  #   mihomo 与网络层的地址冲突，因此客户端侧由下方 ltnetCompat 注入
  #   verge 全局 Merge + Script 兼容层，详见模块注释与
  #   docs/human/network/clash-verge-ltnet-compat.md。
  # - 订阅地址见 greencloud:/var/lib/sublinkpro/unified-subscription.txt
  #   （统一订阅 Clash/Mihomo 链接），在 GUI「订阅」页导入即可。

  # 订阅模板的 fake-ip 网段已直连，这里兜底防止 mihomo DNS 劫持期间的 rp_filter 丢包。
  config = lib.mkMerge [
    {
      programs.clash-verge = {
        enable = true;
        serviceMode = true;
        tunMode = true;
        autoStart = true;
      };

      networking.firewall.checkReversePath = lib.mkForce "loose";
    }
    (lib.mkIf cfg.enable {
      systemd.tmpfiles.settings."clash-verge-ltnet-compat" = {
        # L+ 不创建父目录；d 仅在缺失时兜底创建，不覆盖已有权限。
        "${vergeDataDir}"."d" = owner // {
          mode = "0700";
        };
        "${vergeProfilesDir}"."d" = owner // {
          mode = "0700";
        };
        "${vergeProfilesDir}/Merge.yaml"."L+" = owner // {
          argument = "${mergeYaml}";
          mode = "0644";
        };
        "${vergeProfilesDir}/Script.js"."L+" = owner // {
          argument = "${scriptJs}";
          mode = "0644";
        };
      };
    })
  ];

  options.lantian.clash-verge.ltnetCompat = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Install LTNET/dn42 compatibility overrides (Verge global Merge + Script)
        so clash-verge TUN mode coexists with the project's network design
        (LTNET 198.18.0.0/15 over ZeroTier, netns CoreDNS, networkd main-table
        precedence). Any LTNET member needs this; rationale and troubleshooting
        in docs/human/network/clash-verge-ltnet-compat.md.
      '';
    };
    user = lib.mkOption {
      type = lib.types.str;
      default = "zhyi";
      description = "Primary user whose Verge data directory receives the overrides.";
    };
  };
}
