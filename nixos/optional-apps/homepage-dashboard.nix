{
  LT,
  pkgs,
  config,
  lib,
  inputs,
  ...
}:
let
  backend = "http://127.0.0.1:${LT.portStr.HomepageDashboard}";
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
  homepageLocations = {
    "/" = {
      proxyPass = backend;
    };
    "/api/config/" = {
      proxyPass = backend;
      extraConfig = ''
        proxy_hide_header Cache-Control;
        proxy_hide_header ETag;
        add_header Cache-Control "no-store, must-revalidate";
      '';
    };
    "/icons-custom/".alias = inputs.secrets + "/homepage-dashboard-icons/";
    "/homepage-assets/" = {
      alias = "/etc/homepage-dashboard/assets/";
      extraConfig = ''
        add_header Cache-Control "no-cache, must-revalidate";
      '';
    };
  };
in
{
  imports = [ "${inputs.secrets}/homepage-dashboard-config.nix" ];

  sops.secrets.homepage-dashboard-env = {
    sopsFile = inputs.secrets + "/homepage-dashboard.yaml";
    owner = "homepage-dashboard";
    group = "homepage-dashboard";
    # yaml 文件含嵌套 homepage-dashboard-env 块；显式格式避免被推断为 dotenv
    format = "yaml";
  };

  services.homepage-dashboard = {
    enable = true;
    package = pkgs.homepage-dashboard.override { enableLocalIcons = true; };
    listenPort = LT.port.HomepageDashboard;
    environmentFiles = [ config.sops.secrets.homepage-dashboard-env.path ];

    settings = {
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
      # Ignore errors for network instability
      hideErrors = true;
    };

    # iOS 27 风格液态玻璃，复刻差异：zhyi 个人导航专用样式。
    customCSS = builtins.readFile ./homepage-dashboard.css;

    # 加载 SVG 实时折射玻璃、标签页布局与每日一言。
    customJS = ''
      (() => {
        const script = document.createElement("script");
        script.src = "/homepage-assets/liquid-glass/homepage-orchestrator.js";
        script.defer = true;
        document.head.appendChild(script);
      })();
    '';

    widgets = [
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

  systemd.services.homepage-dashboard.serviceConfig = LT.serviceHarden // {
    DynamicUser = lib.mkForce false;
    User = "homepage-dashboard";
    Group = "homepage-dashboard";
    MemoryDenyWriteExecute = lib.mkForce false;
    SystemCallFilter = lib.mkForce [ ];
  };
  systemd.services.homepage-dashboard.after = [ "sops-install-secrets.service" ];
  systemd.services.homepage-dashboard.requires = [ "sops-install-secrets.service" ];
  systemd.services.homepage-dashboard.environment.HOMEPAGE_ALLOWED_HOSTS = lib.mkForce (
    "homepage.localhost,homepage.${config.networking.hostName}.zhyi.cc,"
    + "localhost:${LT.portStr.HomepageDashboard},127.0.0.1:${LT.portStr.HomepageDashboard}"
  );

  users.users.homepage-dashboard = {
    group = "homepage-dashboard";
    isSystemUser = true;
  };
  users.groups.homepage-dashboard = { };

  environment.etc."homepage-dashboard/assets".source = ./homepage-dashboard-assets;

  lantian.nginxVhosts = {
    "homepage.${config.networking.hostName}.zhyi.cc" = {
      locations = homepageLocations;

      sslCertificate = "lets-encrypt-${config.networking.hostName}.zhyi.cc";
      noIndex.enable = true;
      accessibleBy = "private";
    };
    "homepage.localhost" = {
      listenHTTP.enable = true;
      listenHTTPS.enable = false;

      locations = homepageLocations;

      noIndex.enable = true;
      accessibleBy = "localhost";
    };
  };
}
