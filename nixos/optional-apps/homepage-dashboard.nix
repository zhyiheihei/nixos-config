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
      # 液态玻璃风格：卡片玻璃模糊（背景保持清晰）
      cardBlur = "xl";
      background = {
        image = "https://t.alcy.cc/ysz";
        opacity = 100;
      };
      layout = {
        "公开 · AI 链路" = {
          style = "row";
          columns = 4;
        };
        "公开 · 身份链路" = {
          style = "row";
          columns = 4;
        };
        "公开 · 内容与通讯" = {
          style = "row";
          columns = 4;
        };
        "公开 · 基础设施与运维" = {
          style = "row";
          columns = 4;
        };
        "公开 · 媒体链路" = {
          style = "row";
          columns = 4;
        };
        "公开 · 效率工具" = {
          style = "row";
          columns = 4;
        };
        "私有 · AI 链路" = {
          style = "row";
          columns = 4;
        };
        "私有 · 家庭服务" = {
          style = "row";
          columns = 4;
        };
        "私有 · 媒体与下载" = {
          style = "row";
          columns = 4;
        };
        "私有 · 效率工具与内容" = {
          style = "row";
          columns = 4;
        };
        "私有 · 基础设施与网络" = {
          style = "row";
          columns = 4;
        };
        "私有 · 监控" = {
          style = "row";
          columns = 3;
        };
      };
      # Ignore errors for network instability
      hideErrors = true;
    };

    # iOS 27 风格液态玻璃，复刻差异：zhyi 个人导航专用样式。
    customCSS = ''      :root {
        --homepage-glass-hi: rgba(255, 255, 255, 0.16);
        --homepage-glass-border: rgba(255, 255, 255, 0.14);
        --homepage-ink: rgba(246, 248, 252, 0.96);
        --homepage-muted: rgba(246, 248, 252, 0.58);
        --homepage-shadow: rgba(2, 8, 18, 0.32);
      }

      html,
      body,
      #__next {
        min-height: 100%;
        background: transparent !important;
      }

      #background {
        opacity: 1 !important;
        background-position: center !important;
        background-size: cover !important;
        filter: saturate(1.1) contrast(1.02);
      }

      #page_wrapper::before {
        content: "";
        position: fixed;
        inset: 0;
        z-index: 1;
        pointer-events: none;
        background:
          radial-gradient(120% 70% at 50% 0%, rgba(8, 12, 20, 0.18), transparent 58%),
          linear-gradient(180deg, rgba(5, 8, 14, 0.10), rgba(5, 8, 14, 0.42) 82%);
      }

      #inner_wrapper {
        width: min(100%, 1680px);
        margin: 0 auto;
        padding-bottom: 36px;
      }

      #information-widgets {
        position: sticky;
        top: 16px;
        z-index: 60;
        margin: 20px 28px 12px !important;
        padding: 10px 14px !important;
        border: 1px solid var(--homepage-glass-border) !important;
        border-radius: 28px !important;
        background: linear-gradient(180deg, rgba(255, 255, 255, 0.10), rgba(255, 255, 255, 0.045)) !important;
        backdrop-filter: blur(22px) saturate(170%) !important;
        -webkit-backdrop-filter: blur(22px) saturate(170%) !important;
        box-shadow:
          inset 0 1px 0 rgba(255, 255, 255, 0.18),
          inset 0 -1px 0 rgba(255, 255, 255, 0.04),
          0 18px 44px var(--homepage-shadow) !important;
      }

      #widgets-wrap {
        align-items: center;
      }

      .widget-container {
        display: flex !important;
        align-items: center !important;
        justify-content: center !important;
        min-height: 48px !important;
        margin: 2px 4px !important;
        padding: 6px 12px !important;
        border: 0 !important;
        border-radius: 16px !important;
        background: transparent !important;
        backdrop-filter: none !important;
        -webkit-backdrop-filter: none !important;
        box-shadow: none !important;
      }

      .primary-text,
      .secondary-text,
      .information-widget-greeting,
      .information-widget-datetime,
      .information-widget-openmeteo {
        color: var(--homepage-ink) !important;
      }

      .information-widget-greeting {
        max-width: 640px;
        font-size: 1rem !important;
        line-height: 1.4;
        white-space: normal;
      }

      #homepage-search-section {
        position: relative;
        z-index: 40;
        width: min(100%, 640px);
        margin: 4px auto 20px !important;
        padding: 0 20px;
      }

      .information-widget-search {
        width: 100% !important;
        margin: 0 !important;
      }

      .information-widget-search input {
        height: 3.5rem !important;
        padding: 0 4rem !important;
        border: 1px solid rgba(255, 255, 255, 0.16) !important;
        border-radius: 9999px !important;
        background: rgba(255, 255, 255, 0.09) !important;
        box-shadow:
          inset 0 1px 0 rgba(255, 255, 255, 0.14),
          0 10px 28px rgba(2, 8, 18, 0.22) !important;
        color: var(--homepage-ink) !important;
        font-size: 1rem !important;
        text-align: center;
        transition: border-color 160ms ease, background 160ms ease, box-shadow 160ms ease !important;
      }

      .information-widget-search input::placeholder {
        color: rgba(246, 248, 252, 0.42) !important;
      }

      .information-widget-search input:focus {
        outline: none !important;
        border-color: rgba(140, 165, 255, 0.55) !important;
        background: rgba(255, 255, 255, 0.12) !important;
        box-shadow:
          inset 0 1px 0 rgba(255, 255, 255, 0.16),
          0 0 0 4px rgba(110, 140, 255, 0.16),
          0 14px 32px rgba(2, 8, 18, 0.24) !important;
      }

      .information-widget-search button[aria-haspopup="listbox"] {
        top: 50% !important;
        bottom: auto !important;
        right: 0.6rem !important;
        transform: translateY(-50%) !important;
        border-radius: 9999px !important;
        background: rgba(255, 255, 255, 0.12) !important;
      }

      #services,
      #bookmarks {
        display: block;
      }

      #services {
        margin: 8px 28px 0 !important;
        align-items: stretch;
        gap: 18px;
      }

      #bookmarks {
        margin: 8px 28px 0 !important;
      }

      .homepage-tabbar {
        display: flex;
        justify-content: center;
        gap: 6px;
        max-width: 520px;
        margin: 0 auto 18px;
        padding: 6px;
        border: 1px solid rgba(255, 255, 255, 0.16);
        border-radius: 9999px;
        background: linear-gradient(180deg, rgba(255, 255, 255, 0.10), rgba(255, 255, 255, 0.05));
        backdrop-filter: blur(20px) saturate(170%);
        -webkit-backdrop-filter: blur(20px) saturate(170%);
        box-shadow:
          inset 0 1px 0 rgba(255, 255, 255, 0.16),
          0 12px 32px rgba(2, 8, 18, 0.24);
      }

      .homepage-tab {
        flex: 1;
        max-width: 160px;
        padding: 10px 18px;
        border: 0;
        border-radius: 9999px;
        background: transparent;
        color: rgba(246, 248, 252, 0.62);
        font-size: 0.92rem;
        font-weight: 600;
        letter-spacing: 0;
        cursor: pointer;
        transition: background 160ms ease, color 160ms ease, box-shadow 160ms ease;
      }

      .homepage-tab:hover {
        color: rgba(246, 248, 252, 0.92);
        background: rgba(255, 255, 255, 0.08);
      }

      .homepage-tab.active {
        color: #ffffff;
        background: linear-gradient(180deg, rgba(140, 165, 255, 0.42), rgba(110, 130, 255, 0.28));
        box-shadow:
          inset 0 1px 0 rgba(255, 255, 255, 0.30),
          0 6px 18px rgba(70, 100, 255, 0.22);
      }

      .homepage-tab-panel {
        display: none;
      }

      .homepage-tab-panel.active {
        display: grid;
        grid-template-columns: repeat(2, minmax(0, 1fr));
        gap: 16px;
      }

      .homepage-tab-panel .services-group,
      .homepage-tab-panel .bookmark-group {
        flex: none;
        width: 100%;
        padding: 0 2px !important;
      }

      .homepage-tab-panel .services-list,
      .homepage-tab-panel .bookmark-list {
        grid-template-columns: repeat(2, minmax(0, 1fr)) !important;
      }

      .services-group {
        padding: 0 2px !important;
      }

      .service-group-name {
        min-height: 30px;
        align-items: center;
        color: rgba(246, 248, 252, 0.78) !important;
        font-size: 0.92rem !important;
        font-weight: 600 !important;
        letter-spacing: 0 !important;
      }

      .service-group-name::before {
        content: "";
        width: 4px;
        height: 15px;
        margin-right: 9px;
        border-radius: 9999px;
        background: linear-gradient(180deg, rgba(140, 165, 255, 0.9), rgba(90, 220, 195, 0.7));
        box-shadow: 0 0 12px rgba(120, 150, 255, 0.35);
      }

      .service-card {
        position: relative;
        min-height: 84px;
        margin-bottom: 12px !important;
        padding: 12px 14px !important;
        overflow: hidden;
        border: 1px solid rgba(255, 255, 255, 0.15) !important;
        border-radius: 22px !important;
        background: linear-gradient(145deg, rgba(255, 255, 255, 0.12), rgba(255, 255, 255, 0.04)) !important;
        backdrop-filter: blur(18px) saturate(160%) !important;
        -webkit-backdrop-filter: blur(18px) saturate(160%) !important;
        box-shadow:
          inset 0 1px 0 rgba(255, 255, 255, 0.18),
          inset 0 -1px 0 rgba(255, 255, 255, 0.05),
          0 12px 30px rgba(2, 8, 18, 0.24) !important;
        transition: transform 180ms cubic-bezier(0.2, 0.8, 0.2, 1), border-color 180ms ease, box-shadow 180ms ease, background 180ms ease !important;
      }

      .service-card::before {
        content: "";
        position: absolute;
        inset: 0;
        z-index: 0;
        border-radius: inherit;
        pointer-events: none;
        background: radial-gradient(340px circle at var(--lx, 50%) var(--ly, 0%), rgba(255, 255, 255, 0.16), transparent 58%);
        opacity: 0;
        transition: opacity 180ms ease;
      }

      .service-card:hover {
        transform: translateY(-2px);
        border-color: rgba(255, 255, 255, 0.28) !important;
        background: linear-gradient(145deg, rgba(255, 255, 255, 0.16), rgba(255, 255, 255, 0.06)) !important;
        box-shadow:
          inset 0 1px 0 rgba(255, 255, 255, 0.24),
          inset 0 -1px 0 rgba(255, 255, 255, 0.06),
          0 18px 40px rgba(2, 8, 18, 0.30) !important;
      }

      .service-card:hover::before {
        opacity: 1;
      }

      .service-card:active {
        transform: scale(0.985);
      }

      .service-icon {
        width: 46px;
        height: 46px;
        margin-right: 8px;
        border: 1px solid rgba(255, 255, 255, 0.14);
        border-radius: 15px;
        background: rgba(255, 255, 255, 0.10);
        box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.16);
      }

      .service-icon img,
      .service-icon svg {
        width: 25px;
        height: 25px;
      }

      .service-name {
        font-size: 0.95rem !important;
        font-weight: 650 !important;
        color: rgba(246, 248, 252, 0.96) !important;
        letter-spacing: 0 !important;
      }

      .service-description {
        margin-top: 3px;
        color: rgba(246, 248, 252, 0.55) !important;
        font-size: 0.74rem !important;
        font-weight: 400 !important;
      }

      .service-tags {
        top: 10px !important;
        right: 10px !important;
      }

      .service-tag {
        background: rgba(255, 255, 255, 0.08) !important;
        border: 1px solid rgba(255, 255, 255, 0.10);
        border-radius: 9999px;
        box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.10);
      }

      .bookmark > a {
        position: relative;
        display: block;
        margin-bottom: 10px !important;
        padding: 10px 12px !important;
        overflow: hidden;
        border: 1px solid rgba(255, 255, 255, 0.14) !important;
        border-radius: 18px !important;
        background: linear-gradient(145deg, rgba(255, 255, 255, 0.10), rgba(255, 255, 255, 0.04)) !important;
        backdrop-filter: blur(16px) saturate(160%) !important;
        -webkit-backdrop-filter: blur(16px) saturate(160%) !important;
        box-shadow:
          inset 0 1px 0 rgba(255, 255, 255, 0.16),
          0 8px 24px rgba(2, 8, 18, 0.20) !important;
        transition: transform 180ms cubic-bezier(0.2, 0.8, 0.2, 1), border-color 180ms ease, background 180ms ease, box-shadow 180ms ease !important;
      }

      .bookmark > a:hover {
        transform: translateY(-2px);
        border-color: rgba(255, 255, 255, 0.28) !important;
        background: linear-gradient(145deg, rgba(255, 255, 255, 0.14), rgba(255, 255, 255, 0.06)) !important;
        box-shadow:
          inset 0 1px 0 rgba(255, 255, 255, 0.22),
          0 14px 32px rgba(2, 8, 18, 0.26) !important;
      }

      .bookmark-icon {
        border-radius: 12px !important;
        background: rgba(255, 255, 255, 0.10) !important;
        box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.14);
      }

      .homepage-glass {
        position: relative !important;
        gap: 0 !important;
        padding: 0 !important;
        align-items: stretch !important;
        justify-content: flex-start !important;
        overflow: hidden;
      }

      .homepage-glass > canvas {
        z-index: 0 !important;
        border-radius: inherit !important;
      }

      .homepage-glass > *:not(canvas) {
        position: relative;
        z-index: 1;
      }

      .homepage-glass#information-widgets {
        display: flex !important;
        flex-wrap: wrap !important;
        padding: 10px 14px !important;
      }

      .homepage-glass#homepage-search-section {
        display: block !important;
        padding: 0 20px !important;
      }

      .homepage-glass.service-card {
        display: block !important;
        padding: 12px 14px !important;
      }

      html.webgl-glass .homepage-glass#information-widgets,
      html.webgl-glass .homepage-glass#homepage-search-section {
        border: 0 !important;
        box-shadow: none !important;
      }

      html.webgl-glass .homepage-glass.service-card {
        background: transparent !important;
        backdrop-filter: none !important;
        -webkit-backdrop-filter: none !important;
        border: 1px solid rgba(255, 255, 255, 0.16) !important;
        box-shadow: none !important;
      }

      html.webgl-glass .homepage-glass.service-card:hover {
        border-color: rgba(255, 255, 255, 0.32) !important;
        box-shadow: 0 14px 34px rgba(2, 8, 18, 0.28) !important;
      }

      #footer {
        display: none !important;
      }

      @media (max-width: 768px) {
        #information-widgets {
          top: 10px;
          margin: 12px 12px 8px !important;
          padding: 8px 10px !important;
          border-radius: 22px !important;
        }

        .widget-container {
          min-height: 44px !important;
          padding: 4px 8px !important;
        }

        #homepage-search-section {
          margin: 0 auto 14px !important;
          padding: 0 12px;
        }

        #services {
          margin: 4px 12px 0 !important;
          gap: 14px;
        }

        .homepage-tabbar {
          margin: 0 auto 12px;
        }

        .homepage-tab-panel.active {
          grid-template-columns: 1fr;
          gap: 12px;
        }

        .service-card {
          min-height: 74px;
          padding: 10px 12px !important;
        }

        .service-icon {
          width: 42px;
          height: 42px;
        }
      }

      @media (prefers-reduced-motion: reduce) {
        .service-card,
        .information-widget-search input {
          transition: none !important;
        }

        .service-card:hover {
          transform: none;
        }
      }
    '';

    # 加载 WebGL 液态玻璃、标签页布局与每日一言。
    customJS = ''
      (() => {
        const script = document.createElement("script");
        script.src = "/homepage-assets/liquid-glass/homepage-liquid.js";
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
      locations = {
        "/" = {
          proxyPass = "http://127.0.0.1:${LT.portStr.HomepageDashboard}";
        };
        "/icons-custom/".alias = inputs.secrets + "/homepage-dashboard-icons/";
        "/homepage-assets/".alias = "/etc/homepage-dashboard/assets/";
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
        "/homepage-assets/".alias = "/etc/homepage-dashboard/assets/";
      };

      noIndex.enable = true;
      accessibleBy = "localhost";
    };
  };
}
