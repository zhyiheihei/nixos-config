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

  # LTNET / dn42 豁免规则，与订阅模板 nixos/optional-apps/sublinkpro/clash.yaml
  # 的 rules 段逐字一致（作者为本网络设计的权威版本）。
  ltnetRules = [
    "DOMAIN-SUFFIX,zhyi.xin,DIRECT"
    "DOMAIN-SUFFIX,zhyi.dn42,DIRECT"
    "PROCESS-NAME,zerotier-one,DIRECT"
    "DST-PORT,9993,DIRECT"
    "IP-CIDR,198.18.0.0/15,DIRECT,no-resolve"
    "IP-CIDR6,fdd8:1938:4e88::/48,DIRECT,no-resolve"
    "IP-CIDR,127.0.0.0/8,DIRECT,no-resolve"
    "IP-CIDR,10.0.0.0/8,DIRECT,no-resolve"
    "IP-CIDR,172.16.0.0/12,DIRECT,no-resolve"
    "IP-CIDR,192.168.0.0/16,DIRECT,no-resolve"
    "IP-CIDR,100.64.0.0/10,DIRECT,no-resolve"
    "IP-CIDR6,fc00::/7,DIRECT,no-resolve"
    "IP-CIDR6,fe80::/10,DIRECT,no-resolve"
  ];

  scriptRules = lib.concatStringsSep "\n" (map (r: "    \"${r}\",") ltnetRules);

  # Verge 全局 Merge：TUN/DNS 层面的网络适配。在 Verge 增强链中对每个订阅
  # 深合并生效（实测 2.5.2 下 tun/dns 字段均存活）。
  mergeYaml = pkgs.writeText "clash-verge-merge-ltnet.yaml" ''
    # LTNET / dn42 兼容层 —— 本文件由 NixOS 管理（勿在 Verge GUI 中编辑），
    # 修改请改 nixos/optional-apps/clash-verge.nix。部署后重启 Verge 或重新
    # 激活订阅生效；原理与排障见 docs/human/network/clash-verge-ltnet-compat.md。
    tun:
      # mihomo 默认 TUN 设备地址 198.18.0.1/30 落在 LTNET 198.18.0.0/15
      # （ZeroTier 路由）内；mihomo 同时会在启用 fake-ip 时把设备地址派生为
      # fake-ip-range 的首个 /30，故池子迁出后此地址仅作非 fake-ip 场景兜底。
      inet4-address:
        - 172.19.0.1/30
      # 保险带：overlay 网段显式排除在 TUN 接管之外，防上游 auto-route 行为变化。
      inet4-route-exclude-address:
        - 198.18.0.0/15
        - 10.0.0.0/8
        - 172.16.0.0/12
        - 192.168.0.0/16
        - 100.64.0.0/10
      inet6-route-exclude-address:
        - fdd8:1938:4e88::/48
        - fc00::/7
    dns:
      enable: true
      ipv6: true
      respect-rules: true
      enhanced-mode: fake-ip
      # 默认池 198.18.0.1/16 与 LTNET /15 完全重叠：sing-tun 会强制接管所有
      # dport 53（包括发往本机 netns CoreDNS 的查询）并由 mihomo 应答，fake-ip
      # 随后又被主表 ZeroTier 路由黑洞，TUN 一开全部域名连接超时。迁出至
      # 28.0.0.0/8（未被本机任何路由前缀覆盖；与 FlClash 覆写 28.0.0.1/16 同思路）。
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
      nameserver-policy:
        "geosite:cn,private":
          - https://120.53.53.53/dns-query
          - https://223.5.5.5/dns-query
        "geosite:geolocation-!cn":
          - https://dns.cloudflare.com/dns-query
          - https://dns.google/dns-query
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
