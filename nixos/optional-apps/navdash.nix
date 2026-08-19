{
  LT,
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.lantian.navdash;

  thisHost = config.networking.hostName;

  # Service card collection, mirrored from optional-apps/homepage.nix with one
  # addition: each entry also carries the vhost's accessibleBy value so the
  # portal can hand out public cards anonymously and the full list (private
  # entries included) only to OIDC-authenticated sessions. Like homepage.nix,
  # only cheap option fields (serverName, listenHTTPS.enable, accessibleBy)
  # are read from other hosts' configs to avoid forcing their nginx config.
  ownVhosts = config.lantian.nginxVhosts;
  otherConfigs = lib.filterAttrs (n: _: n != thisHost) LT.self.nixosConfigurations;

  entriesFrom =
    hostName: vhosts:
    lib.flatten (
      lib.mapAttrsToList (
        _: vhost:
        let
          scheme = if vhost.listenHTTPS.enable then "https" else "http";
          # Non-default HTTPS ports (e.g. matrix-federation on 8448) must be
          # carried in the URL, otherwise the probe and the card link hit the
          # wrong port (443) and misreport the service as down.
          port =
            if vhost.listenHTTPS.enable && vhost.listenHTTPS.port != LT.port.HTTPS then
              toString vhost.listenHTTPS.port
            else
              null;
        in
        {
          inherit scheme port;
          name = vhost.serverName;
          src = hostName;
          access = vhost.accessibleBy;
        }
      ) vhosts
    );

  allEntries =
    (entriesFrom thisHost ownVhosts)
    ++ lib.flatten (
      lib.mapAttrsToList (
        n: v: entriesFrom n (lib.attrByPath [ "lantian" "nginxVhosts" ] { } v.config)
      ) otherConfigs
    );

  # 卡片图标：按 vhost serverName 精确映射图标名。映射的图标自托管于
  # secrets 仓库 navdash-icons/（经 /api/icon 下发，不依赖 nasicon.top）；
  # 未映射的条目 icon 为空，前端用服务子域名直试图标站
  # （gemini/transmission 等名字本身就是图标名），仍无则隐藏。
  serviceIcons = {
    "frigate.opi5p.zhyi.cc" = "Frigate_A";
    "handbrake-backend.opi5p.zhyi.cc" = "Handbrake_A";
    "jellyfin-api.rock5c.zhyi.cc" = "Jellyfin_A";
    "jellyfin-backend.opi5p.zhyi.cc" = "Jellyfin_A";
    "searx.localhost" = "Searxng_A";
    "tachidesk-backend.opi5p.zhyi.cc" = "Tachidesk--漫画阅读--qdnas-s";
    "bazarr.rock5c.zhyi.cc" = "Bazarr_A";
    "bitwarden.zhyi.xin" = "Vaultwarden--密码管理--qdnas-s";
    "bt.opi5p.zhyi.cc" = "qBittorrent_A--BT下载器--qdnas-s";
    "bt.router.zhyi.cc" = "qBittorrent_A--BT下载器--qdnas-s";
    "dashboard.zhyi.xin" = "Homepage_A";
    "dav.zhyi.xin" = "WebDav_A--WebDav服务--qdnas-s";
    "dsh.zhyi.xin" = "DeepSeek--深度求索--deepseek.com";
    "element.zhyi.xin" = "Element_A";
    "git.zhyi.xin" = "Gitea_A";
    "ha.opi5p.zhyi.cc" = "HomeAssistant_A--智能家居";
    "ha.zhyi.xin" = "HomeAssistant_A--智能家居";
    "halo.volcengine.zhyi.cc" = "Halo--Halo博客--qdnas-s";
    "immich.zhyi.xin" = "Immich--照片备份--qdnas-s";
    "jellyfin.zhyi.xin" = "Jellyfin_A";
    "matrix-client.zhyi.xin" = "Element_A";
    "matrix-federation.zhyi.xin" = "Element_A";
    "metacubexd.rock5c.zhyi.cc" = "Clash_A";
    "moviepilot.rock5c.zhyi.cc" = "Moviepilot_A";
    "openspeedtest.rock5c.zhyi.cc" = "icon-openspeedtest-2.0.6-all";
    "peerbanhelper.opi5p.zhyi.cc" = "icon-peerbanhelper-9.2.5-x86";
    "prometheus.tencent.zhyi.cc" = "Prometheus_A";
    "prometheus.zhyi.xin" = "Prometheus_A";
    "qnap.zhyi.xin" = "Qnap_A";
    "radarr.rock5c.zhyi.cc" = "Radarr_A";
    "rss.zhyi.xin" = "Miniflux_A";
    "rsshub.zhyi.xin" = "Rsshub_A";
    "searx.tencent.zhyi.cc" = "Searxng_A";
    "seedbox.opi5p.zhyi.cc" = "qBittorrent_A--BT下载器--qdnas-s";
    "sonarr.rock5c.zhyi.cc" = "Sonarr_A";
    "tachidesk.zhyi.xin" = "Tachidesk--漫画阅读--qdnas-s";
    "ai-api.zhyi.xin" = "Chatgpt--ChatGPT--openai.com";
    "ai.zhyi.xin" = "ChatGPT_A--ChatGPT";
    "alert.zhyi.xin" = "Prometheus_B";
    "api.zhyi.xin" = "Nginx_A";
    "asf.zhyi.xin" = "Steam_A";
    "books.zhyi.xin" = "Calibre--电子书管理--qdnas-s";
    "fastapi-dls.rock5c.zhyi.cc" = "Python--Python--python.org";
    "filebox.zhyi.xin" = "Filecodebox--文件快递柜--qdnas-s";
    "google-ssl.zhyi.xin" = "icon-allinssl-1.1.1-x86-1767151027811";
    "google-test-ssl.zhyi.xin" = "icon-allinssl-1.1.1-x86-1767151027811";
    "hub.tencent.zhyi.cc" = "Docker_A";
    "id.zhyi.xin" = "2Fauth_A";
    "ignis.opi5p.zhyi.cc" = "mcp_obsidian";
    "index-helper.zhyi.xin" = "SunPanel_A--面板";
    "index.zhyi.xin" = "SunPanel_A--面板";
    "jproxy.opi5p.zhyi.cc" = "JProxy_A--代理服务";
    "lab.google.zhyi.cc" = "Nginx_B";
    "lab.greencloud.zhyi.cc" = "Nginx_B";
    "lab.hostdare.zhyi.cc" = "Nginx_B";
    "lab.lubancat1.zhyi.cc" = "Nginx_B";
    "lab.ml-2700.zhyi.cc" = "Nginx_B";
    "lab.ml-builder.zhyi.cc" = "Nginx_B";
    "lab.opi5p.zhyi.cc" = "Nginx_B";
    "lab.rock5c.zhyi.cc" = "Nginx_B";
    "lab.tencent.zhyi.cc" = "Nginx_B";
    "lab.volcengine.zhyi.cc" = "Nginx_B";
    "letsencrypt-ssl.zhyi.xin" = "icon-allinssl-1.1.1-x86-1767151027811";
    "letsencrypt-test-ssl.zhyi.xin" = "icon-allinssl-1.1.1-x86-1767151027811";
    "login.zhyi.xin" = "Authelia_A";
    "metapi.tencent.zhyi.cc" = "ChatGPT_B--ChatGPT";
    "nav.zhyi.xin" = "Homepage_C";
    "pt.opi5p.zhyi.cc" = "qBittorrent_A--BT下载器--qdnas-s";
    "tools.zhyi.xin" = "Ittools_A";
    "uni-api.hostdare.zhyi.cc" = "Chatgpt--ChatGPT--openai.com";
    "zerossl.zhyi.xin" = "icon-allinssl-1.1.1-x86-1767151027811";
    "zhyi.xin" = "BlogProject--博客项目";
  };

  # 快捷分组：外部服务商（非本集群 nginx vhost），来源 service-providers.md
  # 「在用」清单。这些是当前项目实际依赖的云主机商、AI、代码托管、DNS、
  # 监控、邮件、网络与存储服务，作为卡片直接外链。
  #
  # icon 走 serviceIcons 同款 /api/icon 自托管机制（secrets 仓库
  # navdash-icons/）。只有 nasicon.top 上确实存在图标的服务商才填 icon
  # （文件名与图标站一致）；其余留空，前端按 name 直试图标站，404 则隐藏
  # 图标、仅显示名称，卡片仍可用。
  quickEntries = [
    # 云主机 / VPS
    { name = "火山引擎"; url = "https://www.volcengine.com"; icon = ""; }
    { name = "腾讯云"; url = "https://cloud.tencent.com"; icon = "Tencent_cloud_A"; }
    { name = "GreenCloud"; url = "https://greencloudvps.com"; icon = ""; }
    { name = "HostDare"; url = "https://hostdare.com"; icon = ""; }
    { name = "Google Cloud"; url = "https://cloud.google.com"; icon = "Google_cloud_A"; }
    # AI / LLM
    { name = "DeepSeek"; url = "https://www.deepseek.com"; icon = "DeepSeek--深度求索--deepseek.com"; }
    { name = "OpenAI"; url = "https://api.openai.com"; icon = "Chatgpt--ChatGPT--openai.com"; }
    { name = "Ollama Cloud"; url = "https://ollama.com"; icon = ""; }
    { name = "火山方舟"; url = "https://console.volcengine.com"; icon = ""; }
    { name = "Hugging Face"; url = "https://huggingface.co"; icon = ""; }
    # 代码托管 / CI / 缓存
    { name = "GitHub"; url = "https://github.com"; icon = "Github_A"; }
    { name = "Cachix"; url = "https://cachix.org"; icon = ""; }
    { name = "NUR"; url = "https://github.com/nix-community/NUR"; icon = ""; }
    # DNS
    { name = "Gcore"; url = "https://gcore.com"; icon = "Gcore_A"; }
    { name = "AliDNS"; url = "https://alidns.com"; icon = ""; }
    { name = "DNSPod"; url = "https://www.dnspod.cn"; icon = ""; }
    { name = "Cloudflare DNS"; url = "https://www.cloudflare.com/dns"; icon = ""; }
    # 日志 / 监控
    { name = "Axiom"; url = "https://www.axiom.co"; icon = ""; }
    { name = "Telegram"; url = "https://telegram.org"; icon = ""; }
    # 邮件
    { name = "AhaSend"; url = "https://ahasend.com"; icon = ""; }
    { name = "MXRoute"; url = "https://mxroute.com"; icon = ""; }
    # 网络 / 身份
    { name = "ZeroTier"; url = "https://www.zerotier.com"; icon = "Zerotier_A"; }
    { name = "DN42"; url = "https://dn42.dev"; icon = ""; }
    { name = "Metered TURN"; url = "https://www.metered.ca"; icon = ""; }
    # 存储 / 镜像
    { name = "QNAP"; url = "https://www.qnap.com"; icon = "Qnap_A"; }
    { name = "DaoCloud"; url = "https://www.daocloud.io"; icon = ""; }
    { name = "jsDelivr"; url = "https://www.jsdelivr.net"; icon = ""; }
    # TLS 证书 CA
    { name = "Let's Encrypt"; url = "https://letsencrypt.org"; icon = ""; }
    { name = "ZeroSSL"; url = "https://zerossl.com"; icon = ""; }
  ];

  # 快捷卡片：name 是标题，URL 行显示真实域名（highlight = 域名，suffix 空），
  # host 显示域名（与自建条目「物理主机」语义对应，这里就是服务商域名）。
  quickEntrySet = map (q: let
    hostname = builtins.head (builtins.match "https?://([^/]+).*" q.url);
  in {
    name = q.name;
    url = q.url;
    proto = "https://";
    highlight = hostname;
    suffix = "";
    host = hostname;
    access = "public";
    group = "快捷";
    icon = q.icon;
  }) quickEntries;

  # Split a hostname into the scheme/proto prefix, the subdomain label to
  # highlight, and the trailing domain suffix to dim. Longest matching suffix
  # wins; see optional-apps/homepage.nix for the POSIX regex reasoning, which
  # this copies verbatim.
  splitName =
    e:
    let
      inherit (e) scheme name src;
      proto = "${scheme}://";
      portSuffix = if e.port == null then "" else ":${e.port}";
      pattern = "(\\.${src}\\.zhyi\\.xin|\\.${src}\\.moliy\\.site|\\.${src}\\.zhyi\\.cc|\\.zhyi\\.xin|\\.moliy\\.site|\\.zhyi\\.cc|\\.localhost|zhyi\\.xin|moliy\\.site|zhyi\\.cc)$";
      parts = builtins.split pattern name;
      # 语义分组：公开 = zhyi.xin（主公开域）；私有 = zhyi.cc / moliy.site /
      # localhost（基础设施、主机名、内网）。前端按此分组，不再按物理主机。
      group =
        if lib.hasSuffix ".zhyi.xin" name || name == "zhyi.xin" then
          "公开"
        else
          "私有";
    in
    if builtins.length parts == 1 then
      {
        url = "${proto}${name}${portSuffix}";
        inherit proto group;
        highlight = name;
        suffix = "";
        host = e.src;
        access = e.access;
        icon = serviceIcons.${name} or "";
      }
    else
      {
        url = "${proto}${name}${portSuffix}";
        inherit proto group;
        highlight = builtins.elemAt parts 0;
        suffix = builtins.elemAt (builtins.elemAt parts 1) 0;
        host = e.src;
        access = e.access;
        icon = serviceIcons.${name} or "";
      };

  entrySet = lib.pipe allEntries [
    (builtins.filter (e: !lib.hasPrefix "_" e.name))
    (builtins.filter (e: !lib.hasInfix "*" e.name))
    (builtins.filter (e: !lib.hasPrefix "www." e.name))
    # .localhost entries are only kept from the current host (they are per-host)
    (builtins.filter (e: !lib.hasSuffix ".localhost" e.name || e.src == thisHost))
    # Not the redundant per-host top-level alias <host>.zhyi.xin,
    # <host>.moliy.site, or <host>.zhyi.cc (subdomains like
    # <svc>.<host>.<domain> are kept, and the root domains zhyi.xin /
    # moliy.site / zhyi.cc themselves are kept)
    (builtins.filter (
      e:
      !(
        e.name == "${e.src}.zhyi.xin"
        || e.name == "${e.src}.moliy.site"
        || e.name == "${e.src}.zhyi.cc"
      )
    ))
    (builtins.map splitName)
    (builtins.foldl' (acc: r: if builtins.any (x: x.url == r.url) acc then acc else acc ++ [ r ]) [ ])
    (builtins.sort (a: b: a.url < b.url))
  ] ++ quickEntrySet;

  entriesJson = (pkgs.formats.json { }).generate "navdash-entries.json" {
    entries = entrySet;
  };
in
{
  options.lantian.navdash = {
    enable = lib.mkEnableOption "navdash personal service portal (nav.zhyi.xin)";

    allowedUsers = lib.mkOption {
      type = lib.types.str;
      default = "zhyi";
      description = "Comma separated preferred_username allowlist for OIDC logins";
    };
  };

  config = lib.mkIf cfg.enable {
    sops.secrets = {
      navdash-oidc-client-secret = {
        sopsFile = inputs.secrets + "/common/dex.yaml";
        key = "dex-navdash-secret";
      };
      navdash-session-key = {
        sopsFile = inputs.secrets + "/common/personal-apps.yaml";
        key = "navdash-session-key";
      };
    };

    # 两个 secret 都是单值，systemd EnvironmentFile 需要 KEY=value 格式，
    # 用 sops 模板拼装；属主对齐专用用户（本仓 dsh-web 同款模式）。
    sops.templates."navdash-env" = {
      content = ''
        NAVDASH_OIDC_CLIENT_SECRET=${config.sops.placeholder.navdash-oidc-client-secret}
        NAVDASH_SESSION_KEY=${config.sops.placeholder.navdash-session-key}
      '';
      owner = "navdash";
      group = "navdash";
      mode = "0440";
    };

    systemd.services.navdash = {
      description = "navdash personal service portal";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      script = ''
        exec ${inputs.zhyi-packages.packages.${pkgs.system}.navdash}/bin/navdash
      '';
      environment = {
        NAVDASH_LISTEN = "127.0.0.1:${LT.portStr.Navdash}";
        NAVDASH_BASE_URL = "https://nav.zhyi.xin";
        NAVDASH_OIDC_ISSUER = "https://login.zhyi.xin";
        NAVDASH_OIDC_CLIENT_ID = "navdash";
        NAVDASH_ALLOWED_USERS = cfg.allowedUsers;
        NAVDASH_ENTRIES = "${entriesJson}";
        NAVDASH_ICON_DIR = "${inputs.secrets}/navdash-icons";
      };
      serviceConfig = LT.serviceHarden // {
        User = "navdash";
        Group = "navdash";
        EnvironmentFile = [ config.sops.templates."navdash-env".path ];
        Restart = "always";
        RestartSec = "5";
      };
    };

    users.users.navdash = {
      group = "navdash";
      isSystemUser = true;
    };
    users.groups.navdash = { };

    lantian.nginxVhosts."nav.zhyi.xin" = {
      locations."/" = {
        proxyPass = "http://127.0.0.1:${LT.portStr.Navdash}";
      };
      sslCertificate = "lets-encrypt-zhyi.xin";
      noIndex.enable = true;
    };
  };
}
