{
  inputs,
  config,
  lib,
  LT,
  pkgs,
  ...
}:
{
  imports = [
    ../../nixos/server.nix

    ./hardware-configuration.nix

    ../../nixos/optional-apps/acme
    ../../nixos/optional-apps/attic.nix
    ../../nixos/optional-apps/bepasty.nix
    ../../nixos/optional-apps/bird-lg-go.nix
    ../../nixos/optional-apps/byparr.nix
    ../../nixos/optional-apps/flapalerted.nix
    ../../nixos/optional-apps/gitea
    ../../nixos/optional-apps/gitea-actions.nix
    ../../nixos/optional-apps/imapfilter.nix
    ../../nixos/optional-apps/lemmy.nix
    ../../nixos/optional-apps/librechat.nix
    ../../nixos/optional-apps/maddy.nix
    ../../nixos/optional-apps/matrix-synapse
    ../../nixos/optional-apps/miniflux.nix
    ../../nixos/optional-apps/n8n
    ../../nixos/optional-apps/netbox.nix
    ../../nixos/optional-apps/nginx-api.nix
    ../../nixos/optional-apps/plausible.nix
    ../../nixos/optional-apps/quassel.nix
    ../../nixos/optional-apps/radicale.nix
    ../../nixos/optional-apps/rsshub.nix
    ../../nixos/optional-apps/rsync-server-ci.nix
    ../../nixos/optional-apps/sublinkpro-nix.nix
    ../../nixos/optional-apps/syncthing
    ../../nixos/optional-apps/tg-bot-cleaner-bot
    ../../nixos/optional-apps/yggdrasil-alfis.nix
    ../../nixos/optional-apps/zerotierone-controller.nix

    ../../nixos/optional-cron-jobs/cleanup-github-notifications
    ../../nixos/optional-cron-jobs/dn42-certificate.nix
    ../../nixos/optional-cron-jobs/radicale-calendar-sync.nix
    ../../nixos/optional-cron-jobs/testssl.nix

    "${inputs.secrets}/nixos-hidden-module/11116c7374949a7a"
    "${inputs.secrets}/nixos-hidden-module/35c68fea6f2bde77"
    "${inputs.secrets}/nixos-hidden-module/94ae14911c8333de"
    "${inputs.secrets}/nixos-hidden-module/c9f6c0c333e73062"
    "${inputs.secrets}/nixos-hidden-module/ca877276fe06bd79"
  ];

  # UniAPI consolidated to hostdare (2026-08-14): LibreChat's upstream moves
  # from the retired rock5c UniAPI to the public ai-api.zhyi.xin entry.
  services.librechat.settings.endpoints.custom = lib.mkForce [
    {
      name = "UniAPI";
      apiKey = "\${UNI_API_KEY}";
      baseURL = "https://ai-api.zhyi.xin/v1";
      models = {
        default = lib.unique (
          lib.concatMap (provider: builtins.map (v: v.value) provider._models)
            config.lantian.llm-providers
        );
        fetch = false;
      };
    }
  ];

  # Preset agents shown in the LibreChat model selector (modelSpecs). MCP
  # server names must match the configured lantian.mcp.toolMcpServers keys.
  services.librechat.settings.modelSpecs = {
    list = [
      {
        name = "general";
        label = "通用助手";
        default = true;
        description = "全能助手：联网搜索、天气、航班、地图、日程、时间。";
        greeting = "你好，我是通用助手。可以帮你查天气、航班、地图、日程，也能联网搜索。";
        conversation_starters = [
          "帮我查一下今天的天气"
          "搜索一下最新的科技新闻"
          "查看我的日历安排"
          "明天从上海到东京有哪些航班"
        ];
        mcpServers = [
          "grok-search-rs"
          "weather"
          "time"
          "caldav"
          "google-maps"
          "adsb-lol"
          "airplanes-live"
        ];
        preset = {
          endpoint = "UniAPI";
          model = "deepseek-v4-flash:opencode-go";
          modelLabel = "DeepSeek V4 Flash";
          temperature = 0.3;
        };
      }
      {
        name = "research";
        label = "搜索研究";
        description = "专注联网搜索与资料研究（grok-search-rs）。";
        greeting = "我可以帮你深度搜索和整理资料。";
        conversation_starters = [
          "帮我调研 NixOS 的 impermanence 方案"
          "搜索最近发布的 AI 论文"
        ];
        mcpServers = [
          "grok-search-rs"
          "time"
        ];
        preset = {
          endpoint = "UniAPI";
          model = "deepseek-v4-flash:opencode-go";
          temperature = 0.2;
        };
      }
      {
        name = "travel";
        label = "出行航班";
        description = "航班追踪、机场信息、地图与天气。";
        greeting = "查航班、看地图、问天气，出行相关找我。";
        conversation_starters = [
          "现在天上有没有经过的航班"
          "查一下某个机场的天气"
        ];
        mcpServers = [
          "adsb-lol"
          "airplanes-live"
          "flightaware"
          "google-maps"
          "weather"
          "time"
        ];
        preset = {
          endpoint = "UniAPI";
          model = "deepseek-v4-flash:opencode-go";
          temperature = 0.3;
        };
      }
    ];
  };

  # Attic talks to the home VaultS3 through the public 8443 entry, whose
  # connect latency is above the AWS SDK's 3.1s default. Keep the public
  # endpoint and only widen the client connect timeout on the Attic host.
  services.atticd.package = lib.mkForce (
    (pkgs.nur-xddxdd.lantianCustomized."attic-telnyx-compatible").overrideAttrs (old: {
      patches = (old.patches or [ ]) ++ [ ../../patches/attic-s3-connect-timeout.patch ];
    })
  );

  networking.domain = lib.mkForce "zhyi.xin";

  systemd.network.networks.eth0 = {
    matchConfig.Name = "eth0";
    address = [
      "203.55.176.158/25"
      "2a11:8083:11:191b::a/64"
    ];
    routes = [
      {
        Destination = "0.0.0.0/0";
        Gateway = "203.55.176.254";
      }
      {
        Destination = "::/0";
        Gateway = "2a11:8083:11::1";
        GatewayOnLink = true;
      }
    ];
    networkConfig.IPv6AcceptRA = "no";
  };

  networking.nameservers = [
    "2001:4860:4860::8888"
    "2001:4860:4860::8844"
  ];

  # Bootstrap files normally generated by the private ltnet-scripts pipeline.
  # The primary sync server owns these paths; generated content can replace them later.
  systemd.tmpfiles.settings.ltnet-scripts = {
    "/nix/sync-servers/ltnet-scripts/pdns-recursor-conf".d = {
      mode = "0755";
      user = "root";
      group = "root";
    };
    "/nix/sync-servers/ltnet-scripts/pdns-recursor-conf/fwd-dn42-interconnect.lua".f = {
      mode = "0644";
      user = "root";
      group = "root";
    };
    "/nix/sync-servers/ltnet-scripts/pdns-recursor-conf/fwd-dn42-interconnect.yml".f = {
      mode = "0644";
      user = "root";
      group = "root";
    };
  };

  lantian.nginxVhosts."greencloud.zhyi.cc".sslCertificate = "lets-encrypt-zhyi.cc";

  # Certificate for dav.<host>.zhyi.xin (WebDAV on opi5p): *.zhyi.xin wildcard
  # does not cover two-level names, so issue a single-domain cert via the
  # existing gcore DNS-01 pipeline and sync through /nix/sync-servers.
  security.acme.certs =
    (pkgs.callPackage ../../nixos/optional-apps/acme/common.nix { inherit config; })
    .mkLetsEncryptCert "opi5p.zhyi.xin";

  # Hydra moved from pve-5700u to ml-builder on 2026-08-12. The common vhost
  # module keeps the upstream pve-epyc target; override only the backend here.
  lantian.nginxVhosts."hydra.zhyi.xin".locations."/".proxyPass = lib.mkForce (
    "http://${LT.hosts.ml-builder.ltnet.IPv4}:${LT.portStr.Hydra}"
  );

  virtualisation.oci-containers.containers.byparr.ports = [
    "${LT.this.ltnet.IPv4}:${LT.portStr.FlareSolverr}:8191"
  ];
  systemd.services.flaresolverr = lib.mkIf config.services.flaresolverr.enable {
    environment.HOST = lib.mkForce LT.this.ltnet.IPv4;
  };

  # n8n ships zh-CN translations; make the editor default to Simplified Chinese.
  services.n8n.environment.N8N_DEFAULT_LOCALE = "zh-CN";

  # Match the user's local Firefox identity so anti-bot sites do not reject the
  # Miniflux fetcher as a non-browser client. Keep RSSHub on the same UA.
  services.miniflux.config.HTTP_CLIENT_USER_AGENT =
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:153.0) Gecko/20100101 Firefox/153.0";
  services.rsshub.settings.UA =
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:153.0) Gecko/20100101 Firefox/153.0";

  # Keep the author's account automation units available, but leave them
  # dormant until this deployment has its own account-specific configuration.
  systemd.services.email-oauth2-proxy.unitConfig.ConditionPathExists =
    "${inputs.secrets}/imapfilter/emailproxy.config";
  systemd.services.imapfilter-outlook.unitConfig.ConditionPathExists =
    "${inputs.secrets}/imapfilter/outlook.lua";
  systemd.services.imapfilter-gmail.unitConfig.ConditionPathExists =
    "${inputs.secrets}/imapfilter/gmail.lua";
  systemd.services.imapfilter-lantian.unitConfig.ConditionPathExists =
    "${inputs.secrets}/imapfilter/lantian.lua";

  systemd.services.tg-bot-cleaner-bot.serviceConfig.ExecCondition = [
    "${pkgs.gnugrep}/bin/grep -qE ^TG_API_ID=.+$ ${config.sops.secrets.tg-bot-cleaner-bot.path}"
    "${pkgs.gnugrep}/bin/grep -qE ^TG_API_HASH=.+$ ${config.sops.secrets.tg-bot-cleaner-bot.path}"
  ];
  systemd.services.cleanup-github-notifications.serviceConfig.ExecCondition =
    "${pkgs.gnugrep}/bin/grep -qE ^GITHUB_TOKEN=.+$ ${config.sops.secrets.cleanup-github-notifications-env.path}";
  environment.systemPackages = with pkgs; [
    gnumake
  ];

  # cn-accel is used for the v2ray exit; skip mihomo to save memory.
  lantian.mihomo.enable = false;

  # The SFTP/data chain moved to OPI5P.  ml-home-vm is offline; keep the
  # author's backup semantics by pointing the endpoint at the migrated host.
  lantian.backup.sftpEndpoint = "opi5p.zhyi.cc";
}
