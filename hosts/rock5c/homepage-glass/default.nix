{
  LT,
  pkgs,
  config,
  lib,
  ...
}:
let
  bootstrapJs = ''
    (() => {
      const script = document.createElement("script");
      script.src = "/homepage-assets/js/homepage-orchestrator.js";
      document.head.appendChild(script);
    })();
  '';
  vendorHtml2Canvas = pkgs.fetchurl {
    url = "https://cdn.jsdelivr.net/npm/html2canvas-pro@1.5.8/dist/html2canvas-pro.min.js";
    hash = "sha256-Vv/S7gkGXkDiEGi19tbFIzccVh/PxqBKcYbE1H5mEPM=";
  };
  homepageLocations = {
    "/api/config/" = {
      proxyPass = "http://127.0.0.1:${LT.portStr.HomepageDashboard}";
      extraConfig = ''
        proxy_hide_header Cache-Control;
        proxy_hide_header ETag;
        add_header Cache-Control "no-store, must-revalidate";
      '';
    };
    "/homepage-assets/js/" = {
      alias = "/etc/homepage-dashboard/assets/js/";
      extraConfig = ''
        add_header Cache-Control "no-cache, must-revalidate";
      '';
    };
    "/homepage-assets/vendor/" = {
      alias = "/etc/homepage-dashboard/assets/vendor/";
      allowCORS = true;
      extraConfig = ''
        add_header Cache-Control "public, immutable, max-age=31536000";
      '';
    };
  };
in
{
  services.homepage-dashboard = {
    settings = {
      theme = lib.mkForce "dark";
      color = lib.mkForce "neutral";
      iconStyle = lib.mkForce "theme";
      statusStyle = lib.mkForce "dot";
    };

    # 仅保留 WebGPU 玻璃层，CSS/JS 均由本模块提供。
    customCSS = lib.mkForce (builtins.readFile ./homepage.css);
    customJS = lib.mkForce bootstrapJs;

    # secrets 的 search widget 与公共模块的 greeting/datetime/openmeteo
    # 保留不动，这里只追加 rock5c 专属的资源监控卡。
    widgets = lib.mkAfter [
      {
        resources = {
          label = "rock5c";
          cpu = true;
          memory = true;
          disk = "/nix";
          uptime = true;
          refresh = 5000;
        };
      }
    ];
  };

  systemd.services.homepage-dashboard.after = [ "sops-install-secrets.service" ];
  systemd.services.homepage-dashboard.requires = [ "sops-install-secrets.service" ];
  systemd.services.homepage-dashboard.environment.HOMEPAGE_ALLOWED_HOSTS = lib.mkForce (
    "homepage.localhost,homepage.${config.networking.hostName}.zhyi.cc,"
    + "localhost:${LT.portStr.HomepageDashboard},127.0.0.1:${LT.portStr.HomepageDashboard}"
  );

  # 契约断言：secrets search + 公共模块三件套 + 本机 resources 各恰好出现一次。
  # 防止 secrets 后续新增同名 widget 或模块被重复导入时静默重复。
  assertions = [
    {
      assertion = let
        widgetKinds = lib.concatMap (w: lib.attrNames w)
          config.services.homepage-dashboard.widgets;
        count = kind: lib.length (lib.filter (k: k == kind) widgetKinds);
      in lib.all (kind: count kind == 1) [
        "search"
        "greeting"
        "datetime"
        "openmeteo"
        "resources"
      ];
      message = "homepage-dashboard widgets must contain search/greeting/datetime/openmeteo/resources exactly once";
    }
    {
      # customCSS/customJS 有意整体替换 secrets 的同名键：rock5c 是
      # homepage-dashboard 的唯一消费者，orchestrator 是 moveSearch 的
      # 唯一所有者；secrets 后续新增 CSS/JS 行为不会再被自动带入。
      assertion =
        config.services.homepage-dashboard.customCSS
        == builtins.readFile ./homepage.css
        && config.services.homepage-dashboard.customJS == bootstrapJs;
      message = "homepage-dashboard customCSS/customJS must stay owned by hosts/rock5c/homepage-glass";
    }
    {
      # html2canvas-pro 版本/SRI 同时出现在 default.nix、orchestrator 的
      # loadScript integrity 与 THIRD_PARTY_NOTICES；升级时必须三处同步。
      # SRI 哈希本身三处强制（orchestrator + notices + default.nix）。
      assertion = lib.hasInfix
        "sha256-Vv/S7gkGXkDiEGi19tbFIzccVh/PxqBKcYbE1H5mEPM="
        (builtins.readFile ./assets/js/homepage-orchestrator.js)
        && lib.hasInfix
          "sha256-Vv/S7gkGXkDiEGi19tbFIzccVh/PxqBKcYbE1H5mEPM="
          (builtins.readFile ./THIRD_PARTY_NOTICES.md)
        && lib.hasInfix "1.5.8" (builtins.readFile ./THIRD_PARTY_NOTICES.md)
        && lib.hasInfix "html2canvas-pro@1.5.8"
          (builtins.readFile ./default.nix)
        && lib.hasInfix
          "sha256-Vv/S7gkGXkDiEGi19tbFIzccVh/PxqBKcYbE1H5mEPM="
          (builtins.readFile ./default.nix);
      message = "html2canvas-pro SRI must match across default.nix / orchestrator / THIRD_PARTY_NOTICES";
    }
    {
      # assets/js 整目录由 vhost alias 服务；WebGPU 后端由 studio-glass.js
      # 运行时加载，若误删文件构建不会失败但线上会静默降级。用 readDir
      # 断言关键文件必须在场。
      assertion = let
        jsFiles = builtins.attrNames (builtins.readDir ./assets/js);
        required = [
          "homepage-orchestrator.js"
          "studio-glass.js"
          "studio-glass-webgpu.js"
        ];
      in lib.all (f: builtins.elem f jsFiles) required;
      message = "hosts/rock5c/homepage-glass/assets/js must keep the orchestrator and both glass backends";
    }
    {
      # 公共模块 vhost 是 locations 的宿主；主机模块只在其上挂资产路由。
      assertion = let
        vhosts = config.lantian.nginxVhosts;
      in lib.all (name:
        vhosts ? ${name}
        && vhosts.${name}.locations ? "/"
        && vhosts.${name}.locations ? "/icons-custom/"
        && vhosts.${name}.locations ? "/api/config/"
        && vhosts.${name}.locations ? "/homepage-assets/js/"
        && vhosts.${name}.locations ? "/homepage-assets/vendor/"
        && vhosts.${name}.locations."/homepage-assets/vendor/".allowCORS == true
        && vhosts.${name}.locations."/homepage-assets/js/".alias
          == "/etc/homepage-dashboard/assets/js/"
        && vhosts.${name}.locations."/homepage-assets/vendor/".alias
          == "/etc/homepage-dashboard/assets/vendor/"
      ) [
        "homepage.${config.networking.hostName}.zhyi.cc"
        "homepage.localhost"
      ];
      message = "homepage nginx vhosts must keep the glass asset locations";
    }
  ];

  environment.etc."homepage-dashboard/assets/js".source = ./assets/js;
  environment.etc."homepage-dashboard/assets/vendor/html2canvas-pro-1.5.8.min.js".source =
    vendorHtml2Canvas;
  environment.etc."homepage-dashboard/assets/vendor/html2canvas-pro-LICENSE.txt".source =
    ./assets/vendor/html2canvas-pro-LICENSE.txt;
  environment.etc."homepage-dashboard/assets/vendor/THIRD_PARTY_NOTICES.md".source =
    ./THIRD_PARTY_NOTICES.md;
  environment.etc."homepage-dashboard/assets/vendor/liquid-glass-studio-LICENSE.txt".source =
    ./LICENSE;

  lantian.nginxVhosts = {
    "homepage.${config.networking.hostName}.zhyi.cc" = {
      locations = homepageLocations;
    };
    "homepage.localhost" = {
      locations = homepageLocations;
    };
  };
}
