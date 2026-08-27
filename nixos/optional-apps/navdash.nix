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
    "frigate.opi5p.zhyi.xin" = "Frigate_A";
    "handbrake-backend.opi5p.zhyi.xin" = "Handbrake_A";
    "jellyfin-api.rock5c.zhyi.xin" = "Jellyfin_A";
    "jellyfin-backend.opi5p.zhyi.xin" = "Jellyfin_A";
    "searx.localhost" = "Searxng_A";
    "tachidesk-backend.opi5p.zhyi.xin" = "Tachidesk--漫画阅读--qdnas-s";
    "bazarr.rock5c.zhyi.xin" = "Bazarr_A";
    "bitwarden.zhyi.xin" = "Vaultwarden--密码管理--qdnas-s";
    "bt.opi5p.zhyi.xin" = "qBittorrent_A--BT下载器--qdnas-s";
    "bt.router.zhyi.xin" = "qBittorrent_A--BT下载器--qdnas-s";
    "dashboard.zhyi.xin" = "Homepage_A";
    "dav.zhyi.xin" = "WebDav_A--WebDav服务--qdnas-s";
    "dsh.zhyi.xin" = "DeepSeek--深度求索--deepseek.com";
    "element.zhyi.xin" = "Element_A";
    "git.zhyi.xin" = "Gitea_A";
    "ha.opi5p.zhyi.xin" = "HomeAssistant_A--智能家居";
    "ha.zhyi.xin" = "HomeAssistant_A--智能家居";
    "halo.volcengine.zhyi.xin" = "Halo--Halo博客--qdnas-s";
    "immich.zhyi.xin" = "Immich--照片备份--qdnas-s";
    "jellyfin.zhyi.xin" = "Jellyfin_A";
    "matrix-client.zhyi.xin" = "Element_A";
    "matrix-federation.zhyi.xin" = "Element_A";
    "metacubexd.rock5c.zhyi.xin" = "Clash_A";
    "moviepilot.rock5c.zhyi.xin" = "Moviepilot_A";
    "openspeedtest.rock5c.zhyi.xin" = "icon-openspeedtest-2.0.6-all";
    "peerbanhelper.opi5p.zhyi.xin" = "icon-peerbanhelper-9.2.5-x86";
    "prometheus.tencent.zhyi.xin" = "Prometheus_A";
    "prometheus.zhyi.xin" = "Prometheus_A";
    "qnap.zhyi.xin" = "Qnap_A";
    "radarr.rock5c.zhyi.xin" = "Radarr_A";
    "rss.zhyi.xin" = "Miniflux_A";
    "rsshub.zhyi.xin" = "Rsshub_A";
    "searx.tencent.zhyi.xin" = "Searxng_A";
    "seedbox.opi5p.zhyi.xin" = "qBittorrent_A--BT下载器--qdnas-s";
    "sonarr.rock5c.zhyi.xin" = "Sonarr_A";
    "tachidesk.zhyi.xin" = "Tachidesk--漫画阅读--qdnas-s";
    "ai-api.zhyi.xin" = "Chatgpt--ChatGPT--openai.com";
    "ai.zhyi.xin" = "ChatGPT_A--ChatGPT";
    "alert.zhyi.xin" = "Prometheus_B";
    "api.zhyi.xin" = "Nginx_A";
    "asf.zhyi.xin" = "Steam_A";
    "attic.zhyi.xin" = "Attic_A";
    "books.zhyi.xin" = "Calibre--电子书管理--qdnas-s";
    "fastapi-dls.rock5c.zhyi.xin" = "Python--Python--python.org";
    "filebox.zhyi.xin" = "Filecodebox--文件快递柜--qdnas-s";
    "google-ssl.zhyi.xin" = "icon-allinssl-1.1.1-x86-1767151027811";
    "hub.tencent.zhyi.xin" = "Docker_A";
    "id.zhyi.xin" = "2Fauth_A";
    "ignis.opi5p.zhyi.xin" = "mcp_obsidian";
    "index-helper.zhyi.xin" = "SunPanel_A--面板";
    "index.zhyi.xin" = "SunPanel_A--面板";
    "jproxy.opi5p.zhyi.xin" = "JProxy_A--代理服务";
    "lab.google.zhyi.xin" = "Nginx_B";
    "lab.greencloud.zhyi.xin" = "Nginx_B";
    "lab.hostdare.zhyi.xin" = "Nginx_B";
    "lab.lubancat1.zhyi.xin" = "Nginx_B";
    "lab.ml-2700.zhyi.xin" = "Nginx_B";
    "lab.ml-builder.zhyi.xin" = "Nginx_B";
    "lab.opi5p.zhyi.xin" = "Nginx_B";
    "lab.rock5c.zhyi.xin" = "Nginx_B";
    "lab.tencent.zhyi.xin" = "Nginx_B";
    "lab.volcengine.zhyi.xin" = "Nginx_B";
    "letsencrypt-ssl.zhyi.xin" = "icon-allinssl-1.1.1-x86-1767151027811";
    "letsencrypt-test-ssl.zhyi.xin" = "icon-allinssl-1.1.1-x86-1767151027811";
    "login.zhyi.xin" = "Authelia_A";
    "metapi.tencent.zhyi.xin" = "ChatGPT_B--ChatGPT";
    "nav.zhyi.xin" = "Homepage_C";
    "pt.opi5p.zhyi.xin" = "qBittorrent_A--BT下载器--qdnas-s";
    "tools.zhyi.xin" = "Ittools_A";
    "uni-api.hostdare.zhyi.xin" = "Chatgpt--ChatGPT--openai.com";
    "zerossl.zhyi.xin" = "icon-allinssl-1.1.1-x86-1767151027811";
    "zhyi.xin" = "BlogProject--博客项目";
  };

  # 卡片功能域分类：按「这张卡片与什么相关」划分，而不是按物理主机或
  # 服务商类型。公开/私有 vhost 的 serverName 精确映射到功能域，恢复自
  # 已删除的 homepage-dashboard 语义分组（01-12）；快捷条目在
  # quickEntries 里按 provider 语义打 category（21-31）。前端在语义分组
  # （公开/私有/快捷）内部再按本值分子节；未命中的条目回退到物理主机名
  # （保持旧行为），避免卡片丢失。
  #
  # 主机根域（<host>.zhyi.xin / lab.<host>.zhyi.xin）是主机可达性/测试页，
  # 统一归到「基础设施与运维」，下面用 genAttrs 生成，避免手写重复。
  serviceCategories =
    {
      # 公开（zhyi.xin）· 内容与通讯
      "zhyi.xin" = "内容与通讯";
      "lemmy.zhyi.xin" = "内容与通讯";
      "rss.zhyi.xin" = "内容与通讯";
      "cal.zhyi.xin" = "内容与通讯";
      "element.zhyi.xin" = "内容与通讯";
      "matrix.zhyi.xin" = "内容与通讯";
      "matrix-client.zhyi.xin" = "内容与通讯";
      "matrix-federation.zhyi.xin" = "内容与通讯";
      "stats.zhyi.xin" = "内容与通讯";
      "pb.zhyi.xin" = "内容与通讯";
      "posts.zhyi.xin" = "内容与通讯";
      "comments.zhyi.xin" = "内容与通讯";
      "mail.zhyi.xin" = "内容与通讯";
      "halo.volcengine.zhyi.xin" = "内容与通讯";
      # 公开 · 身份链路
      "login.zhyi.xin" = "身份链路";
      "id.zhyi.xin" = "身份链路";
      "bitwarden.zhyi.xin" = "身份链路";
      # 公开 · AI 链路
      "ai.zhyi.xin" = "AI 链路";
      "ai-api.zhyi.xin" = "AI 链路";
      "n8n.zhyi.xin" = "AI 链路";
      "metapi.tencent.zhyi.xin" = "AI 链路";
      "uni-api.hostdare.zhyi.xin" = "AI 链路";
      # 公开 · 媒体链路
      "books.zhyi.xin" = "媒体链路";
      "immich.zhyi.xin" = "媒体链路";
      "tachidesk.zhyi.xin" = "媒体链路";
      "jellyfin.zhyi.xin" = "媒体链路";
      "rk-jellyfin.zhyi.xin" = "媒体链路";
      # 公开 · 效率工具
      "tools.zhyi.xin" = "效率工具";
      "index.zhyi.xin" = "效率工具";
      "index-helper.zhyi.xin" = "效率工具";
      "filebox.zhyi.xin" = "效率工具";
      "api.zhyi.xin" = "效率工具";
      "asf.zhyi.xin" = "效率工具";
      "dsh.zhyi.xin" = "效率工具";
      # 公开 · 基础设施与运维
      "hydra.zhyi.xin" = "基础设施与运维";
      "attic.zhyi.xin" = "基础设施与运维";
      "git.zhyi.xin" = "基础设施与运维";
      "netbox.zhyi.xin" = "基础设施与运维";
      "dashboard.zhyi.xin" = "基础设施与运维";
      "prometheus.zhyi.xin" = "基础设施与运维";
      "alert.zhyi.xin" = "基础设施与运维";
      "flapalerted.zhyi.xin" = "基础设施与运维";
      "nav.zhyi.xin" = "基础设施与运维";
      # 公开 · 存储与证书
      "qnap.zhyi.xin" = "存储与证书";
      "dav.zhyi.xin" = "存储与证书";
      "ca.zhyi.xin" = "存储与证书";
      "vaults3.zhyi.xin" = "存储与证书";
      "google-ssl.zhyi.xin" = "存储与证书";
      "letsencrypt-ssl.zhyi.xin" = "存储与证书";
      "letsencrypt-test-ssl.zhyi.xin" = "存储与证书";
      "zerossl.zhyi.xin" = "存储与证书";
      # 私有 · 家庭服务
      "ha.zhyi.xin" = "家庭服务";
      "ha.opi5p.zhyi.xin" = "家庭服务";
      "frigate.opi5p.zhyi.xin" = "家庭服务";
      "syncthing.localhost" = "家庭服务";
      # 私有 · 媒体与下载
      "bt.router.zhyi.xin" = "媒体与下载";
      "bt.opi5p.zhyi.xin" = "媒体与下载";
      "pt.opi5p.zhyi.xin" = "媒体与下载";
      "seedbox.opi5p.zhyi.xin" = "媒体与下载";
      "peerbanhelper.opi5p.zhyi.xin" = "媒体与下载";
      "bitmagnet.opi5p.zhyi.xin" = "媒体与下载";
      "moviepilot.rock5c.zhyi.xin" = "媒体与下载";
      "radarr.rock5c.zhyi.xin" = "媒体与下载";
      "sonarr.rock5c.zhyi.xin" = "媒体与下载";
      "bazarr.rock5c.zhyi.xin" = "媒体与下载";
      "jellyfin-backend.opi5p.zhyi.xin" = "媒体与下载";
      "tachidesk-backend.opi5p.zhyi.xin" = "媒体与下载";
      "handbrake-backend.opi5p.zhyi.xin" = "媒体与下载";
      # 私有 · 效率工具与内容
      "searx.tencent.zhyi.xin" = "效率工具与内容";
      "searx.localhost" = "效率工具与内容";
      "fastapi-dls.rock5c.zhyi.xin" = "效率工具与内容";
      "rsshub.zhyi.xin" = "效率工具与内容";
      "ignis.opi5p.zhyi.xin" = "效率工具与内容";
      # 私有 · 基础设施与网络
      "prometheus.tencent.zhyi.xin" = "基础设施与网络";
      "pve-5700u.zhyi.xin" = "基础设施与网络";
      "metacubexd.rock5c.zhyi.xin" = "基础设施与网络";
      "openspeedtest.rock5c.zhyi.xin" = "基础设施与网络";
      "hub.tencent.zhyi.xin" = "基础设施与网络";
      "jproxy.opi5p.zhyi.xin" = "基础设施与网络";
      "lg.zhyi.xin" = "基础设施与网络";
      "ltnet.zhyi.xin" = "基础设施与网络";
    }
    // lib.genAttrs
      (lib.flatten (lib.mapAttrsToList (h: _: [ "lab.${h}.zhyi.xin" "${h}.zhyi.xin" ]) LT.hosts))
      (_: "基础设施与运维");

  # 卡片上的「实时服务数据」widget。仅公开域可达、且有自管 API 的卡片挂
  # widget：前端把这些 vhost 卡片渲染成服务内部数据（immich 照片数、
  # jellyfin 媒体库、gitea 仓库数），数据由 navdash 后端经 /api/metrics 从
  # 各服务自己的公开 API 拉取（密钥来自 secrets 仓库 navdash-widgets.yaml）。
  # 未命中的卡片 widget 留空，只显示健康探测与静态信息。
  serviceWidgets = {
    "immich.zhyi.xin" = "immich";
    "jellyfin.zhyi.xin" = "jellyfin";
    "git.zhyi.xin" = "gitea";
  };

  # 监控卡片：为每个受监控主机生成一张 prometheusmetric 卡片（node
  # exporter CPU/内存/磁盘利用率），数据经 /api/metrics 从本机 Prometheus
  # （tencent 上 127.0.0.1:9090）拉取。仅登录可见（私有），挂在「基础设施
  # 与运维」功能域下；URL 指向 Grafana 监控大盘（与原 homepage 监控卡一致）。
  # 排除带 client 标签的主机（它们不开 node exporter，无数据可显示），
  # 以及无 node exporter 数据的主机：macmini 是 macOS 无 node exporter；
  # h28k/opi03/taishanpi 处于 bring-up（manualDeploy）阶段，node 抓取
  # target 为 down，实测 CPU/内存查询返回空 result，卡片会显示误导性的 0%。
  noNodeExporterHosts = [ "h28k" "macmini" "opi03" "taishanpi" ];
  monitoredHosts = lib.filterAttrs (
    n: v: !v.hasTag LT.tags.client && !(builtins.elem n noNodeExporterHosts)
  ) LT.hosts;

  monitorEntries = lib.mapAttrsToList (
    hostname: h:
    let
      # 点卡片跳到 Grafana 该 host 的资源面板；没有独立主机入口。
      url = "https://dashboard.zhyi.xin";
    in
    {
      inherit hostname url;
      name = hostname;
      proto = "https://";
      highlight = hostname;
      suffix = "";
      host = hostname;
      access = "private";
      group = "私有";
      icon = "";
      brand = "";
      category = "基础设施与运维";
      widget = "prometheusmetric";
      metric_host = hostname;
    }
  ) monitoredHosts;

  # 快捷分组：外部服务商（非本集群 nginx vhost），来源 service-providers.md
  # 「在用」清单。这些是当前项目实际依赖的云主机商、AI、代码托管、DNS、
  # 监控、邮件、网络与存储服务，作为卡片直接外链。
  #
  # icon 走 serviceIcons 同款 /api/icon 自托管机制（secrets 仓库
  # navdash-icons/）。只有 nasicon.top 上确实存在图标的服务商才填 icon
  # （文件名与图标站一致）；其余留空，前端按 name 直试图标站，404 则隐藏
  # 图标、仅显示名称，卡片仍可用。
  #
  # brand 是 Simple Icons 的 slug（CC0 矢量品牌图标，自托管于 navdash
  # web/assets/js/icons.js）。有品牌标的服务商填 brand，前端内联渲染成
  # 主题感知的 SVG（暗色品牌色在暗色主题下自动换成可见的中性色），不依赖
  # 任何外部图标 CDN；无品牌标的留空。
  quickEntries = [
    # VPS 供应商
    { name = "火山引擎"; url = "https://www.volcengine.com"; icon = ""; brand = ""; category = "VPS 供应商"; }
    { name = "腾讯云"; url = "https://cloud.tencent.com"; icon = "Tencent_cloud_A"; brand = ""; category = "VPS 供应商"; }
    { name = "GreenCloud"; url = "https://greencloudvps.com"; icon = ""; brand = ""; category = "VPS 供应商"; }
    { name = "HostDare"; url = "https://hostdare.com"; icon = ""; brand = ""; category = "VPS 供应商"; }
    { name = "Google Cloud"; url = "https://cloud.google.com"; icon = "Google_cloud_A"; brand = "googlecloud"; category = "VPS 供应商"; }
    # AI 与模型
    { name = "DeepSeek"; url = "https://www.deepseek.com"; icon = "DeepSeek--深度求索--deepseek.com"; brand = "deepseek"; category = "AI 与模型"; }
    { name = "OpenAI"; url = "https://api.openai.com"; icon = "Chatgpt--ChatGPT--openai.com"; brand = ""; category = "AI 与模型"; }
    { name = "Ollama Cloud"; url = "https://ollama.com"; icon = ""; brand = "ollama"; category = "AI 与模型"; }
    { name = "火山方舟"; url = "https://console.volcengine.com"; icon = ""; brand = ""; category = "AI 与模型"; }
    { name = "Hugging Face"; url = "https://huggingface.co"; icon = ""; brand = "huggingface"; category = "AI 与模型"; }
    # 开发与构建
    { name = "GitHub"; url = "https://github.com"; icon = "Github_A"; brand = "github"; category = "开发与构建"; }
    { name = "Cachix"; url = "https://cachix.org"; icon = ""; brand = ""; category = "开发与构建"; }
    { name = "NUR"; url = "https://github.com/nix-community/NUR"; icon = ""; brand = ""; category = "开发与构建"; }
    # 域名与网络
    { name = "Gcore"; url = "https://gcore.com"; icon = "Gcore_A"; brand = "gcore"; category = "域名与网络"; }
    { name = "AliDNS"; url = "https://alidns.com"; icon = ""; brand = ""; category = "域名与网络"; }
    { name = "DNSPod"; url = "https://www.dnspod.cn"; icon = ""; brand = ""; category = "域名与网络"; }
    { name = "Cloudflare DNS"; url = "https://www.cloudflare.com/dns"; icon = ""; brand = "cloudflare"; category = "域名与网络"; }
    # 日志与监控
    { name = "Axiom"; url = "https://www.axiom.co"; icon = ""; brand = ""; category = "日志与监控"; }
    { name = "Telegram"; url = "https://telegram.org"; icon = ""; brand = "telegram"; category = "日志与监控"; }
    # 邮件
    { name = "AhaSend"; url = "https://ahasend.com"; icon = ""; brand = ""; category = "邮件"; }
    { name = "MXRoute"; url = "https://mxroute.com"; icon = ""; brand = ""; category = "邮件"; }
    # 域名与网络（身份/隧道）
    { name = "ZeroTier"; url = "https://www.zerotier.com"; icon = "Zerotier_A"; brand = "zerotier"; category = "域名与网络"; }
    { name = "DN42"; url = "https://dn42.dev"; icon = ""; brand = ""; category = "域名与网络"; }
    { name = "Metered TURN"; url = "https://www.metered.ca"; icon = ""; brand = ""; category = "域名与网络"; }
    # 存储与镜像
    { name = "QNAP"; url = "https://www.qnap.com"; icon = "Qnap_A"; brand = "qnap"; category = "存储与镜像"; }
    { name = "DaoCloud"; url = "https://www.daocloud.io"; icon = ""; brand = ""; category = "存储与镜像"; }
    { name = "jsDelivr"; url = "https://www.jsdelivr.net"; icon = ""; brand = "jsdelivr"; category = "存储与镜像"; }
    # TLS 证书 CA
    { name = "Let's Encrypt"; url = "https://letsencrypt.org"; icon = ""; brand = "letsencrypt"; category = "证书与安全"; }
    { name = "ZeroSSL"; url = "https://zerossl.com"; icon = ""; brand = ""; category = "证书与安全"; }
  ];

  # 快捷卡片：name 是标题，URL 行显示真实域名（highlight = 域名，suffix 空）。
  # host 留空——外部服务商没有「物理主机」概念，域名已在 URL 行展示，meta 行
  # 只保留状态点，避免重复。
  quickEntrySet = map (q: let
    hostname = builtins.head (builtins.match "https?://([^/]+).*" q.url);
  in {
    name = q.name;
    url = q.url;
    proto = "https://";
    highlight = hostname;
    suffix = "";
    host = "";
    access = "public";
    group = "快捷";
    icon = q.icon;
    brand = q.brand;
    category = q.category;
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
      pattern = "(\\.${src}\\.zhyi\\.xin|\\.${src}\\.zhyi\\.cc|\\.zhyi\\.xin|\\.zhyi\\.cc|\\.localhost|zhyi\\.xin|zhyi\\.cc)$";
      parts = builtins.split pattern name;
      # 语义分组：公开 = zhyi.xin（主公开域）；私有 = zhyi.xin / 
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
        brand = "";
        category = serviceCategories.${name} or "";
        widget = serviceWidgets.${name} or "";
        metric_host = "";
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
        brand = "";
        category = serviceCategories.${name} or "";
        widget = serviceWidgets.${name} or "";
        metric_host = "";
      };

  entrySet = lib.pipe allEntries [
    (builtins.filter (e: !lib.hasPrefix "_" e.name))
    (builtins.filter (e: !lib.hasInfix "*" e.name))
    (builtins.filter (e: !lib.hasPrefix "www." e.name))
    # .localhost entries are only kept from the current host (they are per-host)
    (builtins.filter (e: !lib.hasSuffix ".localhost" e.name || e.src == thisHost))
    # Not the redundant per-host top-level alias <host>.zhyi.xin
    # (subdomains like <svc>.<host>.<domain> are kept, and the root domain
    # zhyi.xin itself is kept)
    (builtins.filter (
      e:
      !(
        e.name == "${e.src}.zhyi.xin"
        || e.name == "${e.src}.zhyi.xin"
      )
    ))
    (builtins.map splitName)
    (builtins.foldl' (acc: r: if builtins.any (x: x.url == r.url) acc then acc else acc ++ [ r ]) [ ])
    (builtins.sort (a: b: a.url < b.url))
  ] ++ quickEntrySet ++ monitorEntries;

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
      # 服务内部数据 widget 的 API 密钥（immich/jellyfin/gitea），恢复自已
      # 删除的 homepage-dashboard.yaml 的 homepage-dashboard-env 块。仅在
      # tencent 上部署（navdash 与这些服务的公开 API 同网可达）。
      navdash-widget-immich = {
        sopsFile = inputs.secrets + "/navdash-widgets.yaml";
        key = "immich-api-key";
      };
      navdash-widget-jellyfin = {
        sopsFile = inputs.secrets + "/navdash-widgets.yaml";
        key = "jellyfin-api-key";
      };
      navdash-widget-gitea = {
        sopsFile = inputs.secrets + "/navdash-widgets.yaml";
        key = "gitea-api-key";
      };
    };

    # 单值 secret 拼装成 systemd EnvironmentFile；属主对齐专用用户
    # （本仓 dsh-web 同款模式）。
    sops.templates."navdash-env" = {
      content = ''
        NAVDASH_OIDC_CLIENT_SECRET=${config.sops.placeholder.navdash-oidc-client-secret}
        NAVDASH_SESSION_KEY=${config.sops.placeholder.navdash-session-key}
        NAVDASH_WIDGET_IMMICH_KEY=${config.sops.placeholder.navdash-widget-immich}
        NAVDASH_WIDGET_JELLYFIN_KEY=${config.sops.placeholder.navdash-widget-jellyfin}
        NAVDASH_WIDGET_GITEA_KEY=${config.sops.placeholder.navdash-widget-gitea}
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
        # navdash 与 Prometheus 同在 tencent（nav.zhyi.xin 与监控栈同机），
        # 直接打本机只读 Prometheus 即可，无需走 nginx vhost / 认证。
        NAVDASH_PROMETHEUS_URL = "http://127.0.0.1:${LT.portStr.Prometheus.Daemon}";
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
