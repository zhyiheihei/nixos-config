{
  LT,
  pkgs,
  config,
  lib,
  inputs,
  ...
}:
{
  imports = [ "${inputs.secrets}/homepage-dashboard-config.nix" ];

  sops.secrets.homepage-dashboard-env = {
    sopsFile = inputs.secrets + "/homepage-dashboard.yaml";
    owner = "homepage-dashboard";
    group = "homepage-dashboard";
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
      background = {
        image = "/homepage-assets/city-night.jpg";
        opacity = 100;
      };
      layout = {
        "基础设施" = {
          style = "row";
          columns = 4;
        };
        "公开服务" = {
          style = "row";
          columns = 4;
        };
        "家庭服务" = {
          style = "row";
          columns = 5;
        };
        "媒体管理" = {
          style = "row";
          columns = 6;
        };
      };
      # Ignore errors for network instability
      hideErrors = true;
    };

    customCSS = ''
      :root {
        --dashboard-ink: rgba(8, 11, 15, 0.82);
        --dashboard-panel: rgba(16, 20, 25, 0.9);
        --dashboard-line: rgba(255, 255, 255, 0.12);
        --dashboard-cyan: #58e1d2;
        --dashboard-coral: #ff6f7d;
        --dashboard-yellow: #f7c95c;
        --dashboard-mint: #7de2a5;
      }

      #footer {
        display: none !important;
      }

      html,
      body,
      #__next {
        min-height: 100%;
        background: #070b10 url("/homepage-assets/city-night.jpg") center / cover fixed no-repeat !important;
      }

      #background {
        opacity: 1 !important;
        background-position: center !important;
        background-size: cover !important;
        filter: saturate(1.12) contrast(1.05);
      }

      #page_wrapper::before {
        content: "";
        position: fixed;
        inset: 0;
        z-index: 1;
        pointer-events: none;
        background: rgba(4, 7, 11, 0.3);
      }

      #inner_wrapper {
        width: min(100%, 1600px);
        padding-bottom: 32px;
      }

      #information-widgets {
        margin: 28px 32px 8px !important;
        padding: 14px 18px !important;
        border: 1px solid var(--dashboard-line) !important;
        border-radius: 8px !important;
        background: var(--dashboard-ink) !important;
        box-shadow: 0 18px 44px rgba(0, 0, 0, 0.32);
      }

      .widget-container {
        min-height: 52px;
        padding: 4px 10px;
      }

      #services {
        margin: 18px 28px 0 !important;
        align-items: stretch;
      }

      .services-group {
        padding: 6px !important;
      }

      .service-group-name {
        min-height: 34px;
        align-items: center;
        color: rgba(255, 255, 255, 0.94) !important;
        font-size: 1rem !important;
        font-weight: 700 !important;
        letter-spacing: 0 !important;
      }

      .service-card {
        position: relative;
        min-height: 72px;
        margin-bottom: 10px !important;
        padding: 8px !important;
        overflow: hidden;
        border: 1px solid var(--dashboard-line) !important;
        border-radius: 6px !important;
        background-color: var(--dashboard-panel) !important;
        box-shadow: 0 10px 26px rgba(0, 0, 0, 0.24) !important;
        transition: transform 160ms ease, border-color 160ms ease, box-shadow 160ms ease !important;
      }

      .service-card:hover {
        transform: translateY(-2px);
        border-color: rgba(255, 255, 255, 0.28) !important;
        box-shadow: 0 16px 34px rgba(0, 0, 0, 0.34) !important;
      }

      .service-name {
        font-size: 0.92rem !important;
        font-weight: 700 !important;
        letter-spacing: 0 !important;
      }

      .service-description {
        margin-top: 2px;
        color: rgba(255, 255, 255, 0.6) !important;
        font-size: 0.72rem !important;
        font-weight: 500 !important;
      }

      .service-tags {
        top: 7px !important;
        right: 7px !important;
      }

      .services-group:nth-child(1) .service-card {
        border-top: 3px solid var(--dashboard-cyan) !important;
        background-color: rgba(10, 24, 27, 0.94) !important;
        background-image:
          linear-gradient(90deg, rgba(88, 225, 210, 0.1) 1px, transparent 1px),
          linear-gradient(rgba(88, 225, 210, 0.07) 1px, transparent 1px) !important;
        background-size: 18px 18px !important;
      }

      .services-group:nth-child(1) .service-card::after {
        content: "";
        position: absolute;
        top: 8px;
        right: 8px;
        width: 20px;
        height: 2px;
        background: var(--dashboard-cyan);
        opacity: 0.65;
      }

      .services-group:nth-child(2) .service-card {
        min-height: 80px;
        padding-left: 14px !important;
        border-left: 4px solid var(--dashboard-coral) !important;
        background-color: rgba(28, 17, 22, 0.94) !important;
        box-shadow:
          inset 10px 0 24px rgba(255, 111, 125, 0.08),
          0 10px 26px rgba(0, 0, 0, 0.24) !important;
      }

      .services-group:nth-child(3) .service-card {
        min-height: 52px;
        border-bottom: 3px solid var(--dashboard-yellow) !important;
        background-color: rgba(27, 24, 16, 0.94) !important;
        background-image: linear-gradient(135deg, transparent 72%, rgba(247, 201, 92, 0.1) 72%) !important;
      }

      .services-group:nth-child(3) .service-description {
        display: none;
      }

      .services-group:nth-child(4) .service-card {
        min-height: 78px;
        padding: 11px 12px !important;
        border-right: 3px solid var(--dashboard-mint) !important;
        background-color: rgba(14, 25, 20, 0.94) !important;
        box-shadow:
          inset 0 0 0 1px rgba(125, 226, 165, 0.07),
          0 10px 26px rgba(0, 0, 0, 0.24) !important;
      }

      .services-group:nth-child(4) .service-name {
        font-size: 0.88rem !important;
      }

      @media (max-width: 768px) {
        #information-widgets {
          margin: 14px 12px 6px !important;
          padding: 10px 12px !important;
        }

        #services {
          margin: 10px 8px 0 !important;
        }

        .service-card {
          min-height: 64px;
        }

        html,
        body,
        #__next {
          background-attachment: scroll !important;
        }
      }
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
          label = "ml-home-vm";
          cpu = true;
          memory = true;
          disk = "/mnt/storage";
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
  systemd.services.homepage-dashboard.environment.HOMEPAGE_ALLOWED_HOSTS = lib.mkForce (
    "homepage.${config.networking.hostName}.zhyi.cc,homepage.localhost,"
    + "localhost:${LT.portStr.HomepageDashboard},127.0.0.1:${LT.portStr.HomepageDashboard}"
  );

  users.users.homepage-dashboard = {
    group = "homepage-dashboard";
    isSystemUser = true;
  };
  users.groups.homepage-dashboard = { };

  lantian.nginxVhosts = {
    "homepage.${config.networking.hostName}.zhyi.cc" = {
      locations = {
        "/" = {
          proxyPass = "http://127.0.0.1:${LT.portStr.HomepageDashboard}";
          enableOAuth = true;
        };
        "/icons-custom/".alias = inputs.secrets + "/homepage-dashboard-icons/";
        "/homepage-assets/".alias = builtins.toString ./homepage-dashboard-assets + "/";
      };

      sslCertificate = "lets-encrypt-${config.networking.hostName}.zhyi.cc";
      noIndex.enable = true;
      accessibleBy = "private";
    };
    "homepage.localhost" = {
      listenHTTP.enable = true;
      listenHTTPS.enable = false;

      locations = {
        "/" = {
          proxyPass = "http://127.0.0.1:${LT.portStr.HomepageDashboard}";
        };
        "/icons-custom/".alias = inputs.secrets + "/homepage-dashboard-icons/";
        "/homepage-assets/".alias = builtins.toString ./homepage-dashboard-assets + "/";
      };

      noIndex.enable = true;
      accessibleBy = "localhost";
    };
  };
}
