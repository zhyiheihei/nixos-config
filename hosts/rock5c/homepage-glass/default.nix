{
  LT,
  pkgs,
  config,
  lib,
  ...
}:
let
  mkRowLayout = columns: {
    style = "row";
    inherit columns;
  };
  publicGroups = [
    "AI 链路"
    "身份链路"
    "内容与通讯"
    "基础设施与运维"
    "媒体链路"
    "效率工具"
  ];
  privateGroups = [
    "AI 链路"
    "家庭服务"
    "媒体与下载"
    "效率工具与内容"
    "基础设施与网络"
  ];
  layout = lib.genAttrs (map (name: "公开 · ${name}") publicGroups) (_: mkRowLayout 4)
    // lib.genAttrs (map (name: "私有 · ${name}") privateGroups) (_: mkRowLayout 4)
    // { "私有 · 监控" = mkRowLayout 3; };
  vendorHtml2Canvas = pkgs.fetchurl {
    url = "https://cdn.jsdelivr.net/npm/html2canvas-pro@1.5.8/dist/html2canvas-pro.min.js";
    hash = "sha256-1wqhcrzd9i46f55a1ing3xb1qdr3qpbgddb823i40ph617pd5zsn";
  };
in
{
  services.homepage-dashboard = {
    settings = lib.mkForce {
      title = "Zh Yi @ Dashboard";
      theme = "dark";
      color = "neutral";
      headerStyle = "clean";
      language = "zh-CN";
      target = "_blank";
      disableCollapse = true;
      hideVersion = true;
      iconStyle = "theme";
      statusStyle = "dot";
      inherit layout;
      hideErrors = true;
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

    widgets = lib.mkForce [
      {
        greeting = {
          text_size = "xl";
          text = config.services.homepage-dashboard.settings.title;
        };
      }
      {
        datetime = {
          text_size = "xl";
          format = {
            dateStyle = "short";
            timeStyle = "short";
            hour12 = true;
          };
        };
      }
      {
        openmeteo = {
          latitude = LT.this.city.lat;
          longitude = LT.this.city.lng;
          timezone = config.time.timeZone;
          units = "metric";
          cache = 5;
          format.maximumFractionDigits = 1;
        };
      }
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

  environment.etc."homepage-dashboard/assets/js".source = ./assets/js;
  environment.etc."homepage-dashboard/assets/vendor/html2canvas-pro-1.5.8.min.js".source =
    vendorHtml2Canvas;

  lantian.nginxVhosts = {
    "homepage.${config.networking.hostName}.zhyi.cc" = {
      locations = {
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
    };
    "homepage.localhost" = {
      locations = {
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
    };
  };
}
