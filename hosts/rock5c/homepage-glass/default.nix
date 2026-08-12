{
  LT,
  pkgs,
  config,
  lib,
  ...
}:
let
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
      extraConfig = ''
        add_header Cache-Control "public, immutable, max-age=31536000";
      '';
    };
  };
in
{
  services.homepage-dashboard = {
    settings = {
      theme = "dark";
      color = "neutral";
      iconStyle = "theme";
      statusStyle = "dot";
    };

    # 仅保留 WebGL 玻璃层，CSS/JS 均由本模块提供。
    customCSS = lib.mkForce (builtins.readFile ./homepage.css);
    customJS = lib.mkForce ''
      (() => {
        const script = document.createElement("script");
        script.src = "/homepage-assets/js/homepage-orchestrator.js";
        document.head.appendChild(script);
      })();
    '';

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
  ];

  environment.etc."homepage-dashboard/assets/js".source = ./assets/js;
  environment.etc."homepage-dashboard/assets/vendor/html2canvas-pro-1.5.8.min.js".source =
    vendorHtml2Canvas;

  lantian.nginxVhosts = {
    "homepage.${config.networking.hostName}.zhyi.cc" = {
      locations = homepageLocations;
    };
    "homepage.localhost" = {
      locations = homepageLocations;
    };
  };
}
