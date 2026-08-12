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
        font-family: -apple-system, BlinkMacSystemFont, "SF Pro Display", "SF Pro Text", "PingFang SC", "Helvetica Neue", sans-serif !important;
        -webkit-font-smoothing: antialiased;
      }

      #background {
        opacity: 1 !important;
        background-position: center !important;
        background-size: cover !important;
        filter: saturate(1.22) contrast(1.04) brightness(0.92);
      }

      #page_wrapper::before {
        content: "";
        position: fixed;
        inset: 0;
        z-index: 1;
        pointer-events: none;
        background:
          linear-gradient(180deg, rgba(90, 120, 255, 0.10), transparent 28%),
          linear-gradient(180deg, rgba(5, 8, 14, 0.16), rgba(5, 8, 14, 0.52) 86%);
      }

      #inner_wrapper {
        width: min(100%, 1440px);
        margin: 0 auto;
        padding-bottom: 36px;
      }

      #homepage-statusbar {
        position: relative;
        z-index: 70;
        display: flex;
        align-items: center;
        justify-content: space-between;
        height: 44px;
        padding: 0 32px;
        color: rgba(255, 255, 255, 0.94);
        font-size: 15px;
        font-weight: 600;
        letter-spacing: 0;
        pointer-events: none;
      }

      .homepage-status-time {
        font-variant-numeric: tabular-nums;
      }

      .homepage-status-icons {
        display: flex;
        align-items: center;
        gap: 7px;
      }

      .homepage-status-signal {
        display: flex;
        align-items: flex-end;
        gap: 2px;
        height: 11px;
      }

      .homepage-status-signal i {
        width: 3px;
        border-radius: 1.5px;
        background: currentColor;
      }

      .homepage-status-signal i:nth-child(1) { height: 4px; }
      .homepage-status-signal i:nth-child(2) { height: 6px; }
      .homepage-status-signal i:nth-child(3) { height: 8px; }
      .homepage-status-signal i:nth-child(4) { height: 11px; }

      .homepage-status-network {
        font-size: 13px;
        font-weight: 700;
      }

      .homepage-status-battery {
        position: relative;
        width: 24px;
        height: 12px;
        border: 1px solid rgba(255, 255, 255, 0.85);
        border-radius: 3.5px;
      }

      .homepage-status-battery::before {
        content: "";
        position: absolute;
        inset: 2px;
        border-radius: 1.5px;
        background: currentColor;
      }

      .homepage-status-battery::after {
        content: "";
        position: absolute;
        top: 3px;
        right: -3.5px;
        width: 2px;
        height: 5px;
        border-radius: 0 2px 2px 0;
        background: rgba(255, 255, 255, 0.85);
      }

      .hp-clock {
        display: flex;
        flex-direction: column;
        align-items: flex-start;
        line-height: 1;
      }

      .hp-clock-time {
        font-size: 3.4rem !important;
        font-weight: 200 !important;
        letter-spacing: -0.02em;
        color: rgba(255, 255, 255, 0.98);
      }

      .hp-clock-date {
        margin-top: 7px;
        font-size: 1rem !important;
        font-weight: 500;
        color: rgba(255, 255, 255, 0.72);
      }

      .information-widget-datetime {
        flex: 1 1 auto;
        min-width: 260px;
        min-height: 64px !important;
        padding: 0 16px !important;
        border: 0 !important;
        background: transparent !important;
        box-shadow: none !important;
      }

      #information-widgets {
        position: static;
        z-index: 60;
        margin: 26px 28px 10px !important;
        padding: 0 !important;
        border: 0 !important;
        border-radius: 0 !important;
        background: transparent !important;
        backdrop-filter: none !important;
        -webkit-backdrop-filter: none !important;
        box-shadow: none !important;
      }

      #widgets-wrap {
        align-items: center;
        gap: 8px;
      }

      .widget-container {
        display: flex !important;
        align-items: center !important;
        justify-content: center !important;
        min-height: 46px !important;
        margin: 4px 4px !important;
        padding: 8px 14px !important;
        border: 1px solid rgba(255, 255, 255, 0.12) !important;
        border-radius: 16px !important;
        background: rgba(255, 255, 255, 0.07) !important;
        backdrop-filter: blur(18px) saturate(160%) !important;
        -webkit-backdrop-filter: blur(18px) saturate(160%) !important;
        box-shadow:
          inset 0 1px 0 rgba(255, 255, 255, 0.14),
          0 8px 24px rgba(2, 8, 18, 0.16) !important;
      }

      .primary-text,
      .secondary-text,
      .information-widget-greeting,
      .information-widget-datetime,
      .information-widget-openmeteo {
        color: var(--homepage-ink) !important;
      }

      .information-widget-greeting {
        max-width: 520px;
        font-size: 1.05rem !important;
        font-weight: 600 !important;
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
        height: 3.25rem !important;
        padding: 0 3.5rem 0 1.25rem !important;
        border: 1px solid rgba(255, 255, 255, 0.16) !important;
        border-radius: 16px !important;
        background: rgba(255, 255, 255, 0.09) !important;
        box-shadow:
          inset 0 1px 0 rgba(255, 255, 255, 0.14),
          0 10px 28px rgba(2, 8, 18, 0.22) !important;
        color: var(--homepage-ink) !important;
        font-size: 1rem !important;
        text-align: left;
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
        gap: 4px;
        max-width: 520px;
        margin: 0 auto 18px;
        padding: 4px;
        border: 1px solid rgba(255, 255, 255, 0.14);
        border-radius: 14px;
        background: rgba(255, 255, 255, 0.08);
        backdrop-filter: blur(18px) saturate(160%);
        -webkit-backdrop-filter: blur(18px) saturate(160%);
        box-shadow:
          inset 0 1px 0 rgba(255, 255, 255, 0.14),
          0 10px 28px rgba(2, 8, 18, 0.20);
      }

      .homepage-tab {
        flex: 1;
        max-width: 160px;
        padding: 9px 18px;
        border: 0;
        border-radius: 10px;
        background: transparent;
        color: rgba(246, 248, 252, 0.62);
        font-size: 0.88rem;
        font-weight: 590;
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
        background: rgba(255, 255, 255, 0.18);
        box-shadow:
          inset 0 1px 0 rgba(255, 255, 255, 0.24),
          0 4px 14px rgba(2, 8, 18, 0.16);
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
        padding: 8px !important;
        overflow: hidden;
        border: 1px solid rgba(255, 255, 255, 0.14);
        border-radius: 20px;
        background: rgba(255, 255, 255, 0.06);
        backdrop-filter: blur(18px) saturate(160%);
        -webkit-backdrop-filter: blur(18px) saturate(160%);
        box-shadow:
          inset 0 1px 0 rgba(255, 255, 255, 0.12),
          0 10px 28px rgba(2, 8, 18, 0.16);
      }

      .homepage-tab-panel .services-list,
      .homepage-tab-panel .bookmark-list {
        display: block;
      }

      .services-group {
        padding: 0 2px !important;
      }

      .service-group-name {
        min-height: 26px;
        align-items: center;
        color: rgba(246, 248, 252, 0.52) !important;
        font-size: 0.78rem !important;
        font-weight: 600 !important;
        letter-spacing: 0.06em !important;
      }

      .service-group-name::before {
        display: none;
      }

      .service-card {
        position: relative;
        min-height: 64px;
        margin-bottom: 0 !important;
        padding: 8px 6px !important;
        overflow: hidden;
        border: 0 !important;
        border-radius: 12px !important;
        background: transparent !important;
        backdrop-filter: none !important;
        -webkit-backdrop-filter: none !important;
        box-shadow: none !important;
        transition: transform 180ms cubic-bezier(0.2, 0.8, 0.2, 1), border-color 180ms ease, box-shadow 180ms ease, background 180ms ease !important;
      }

      .service:not(:last-child) .service-card {
        border-bottom: 1px solid rgba(255, 255, 255, 0.08) !important;
        border-radius: 12px 12px 0 0 !important;
      }

      .service-card::before {
        content: "";
        position: absolute;
        inset: 0;
        z-index: 0;
        border-radius: inherit;
        pointer-events: none;
        background: radial-gradient(320px circle at var(--lx, 50%) var(--ly, 0%), rgba(255, 255, 255, 0.10), transparent 58%);
        opacity: 0;
        transition: opacity 180ms ease;
      }

      .service-card:hover {
        transform: none;
        background: rgba(255, 255, 255, 0.05) !important;
      }

      .service-card:hover::before {
        opacity: 1;
      }

      .service-card:active {
        transform: scale(0.985);
      }

      .service-icon {
        width: 42px;
        height: 42px;
        margin-right: 8px;
        border: 1px solid rgba(255, 255, 255, 0.14);
        border-radius: 12px;
        background: rgba(255, 255, 255, 0.12);
        box-shadow:
          inset 0 1px 0 rgba(255, 255, 255, 0.18),
          0 2px 8px rgba(2, 8, 18, 0.12);
      }

      .service-icon img,
      .service-icon svg {
        width: 24px;
        height: 24px;
      }

      .service-name {
        font-size: 0.92rem !important;
        font-weight: 600 !important;
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
        margin-bottom: 0 !important;
        padding: 8px 6px !important;
        overflow: hidden;
        border: 0 !important;
        border-radius: 12px !important;
        background: transparent !important;
        backdrop-filter: none !important;
        -webkit-backdrop-filter: none !important;
        box-shadow: none !important;
        transition: transform 180ms cubic-bezier(0.2, 0.8, 0.2, 1), border-color 180ms ease, background 180ms ease, box-shadow 180ms ease !important;
      }

      .bookmark:not(:last-child) > a {
        border-bottom: 1px solid rgba(255, 255, 255, 0.08) !important;
        border-radius: 12px 12px 0 0 !important;
      }

      .bookmark > a:hover {
        transform: none;
        background: rgba(255, 255, 255, 0.05) !important;
      }

      .bookmark-icon {
        border-radius: 10px !important;
        background: rgba(255, 255, 255, 0.11) !important;
        box-shadow:
          inset 0 1px 0 rgba(255, 255, 255, 0.16),
          0 2px 8px rgba(2, 8, 18, 0.10);
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

      .homepage-glass#homepage-search-section {
        display: block !important;
        padding: 0 20px !important;
      }

      .homepage-glass.widget-container {
        display: flex !important;
        padding: 8px 14px !important;
      }

      .homepage-glass.homepage-tabbar {
        display: flex !important;
        padding: 4px !important;
      }

      .homepage-glass.services-group,
      .homepage-glass.bookmark-group {
        display: block !important;
        padding: 8px !important;
      }

      .homepage-glass.service-card {
        display: block !important;
        padding: 10px 12px !important;
      }

      html.webgl-glass .homepage-glass {
        background: transparent !important;
        backdrop-filter: none !important;
        -webkit-backdrop-filter: none !important;
      }

      html.webgl-glass .homepage-glass#homepage-search-section,
      html.webgl-glass .homepage-glass.widget-container,
      html.webgl-glass .homepage-glass.homepage-tabbar,
      html.webgl-glass .homepage-glass.services-group,
      html.webgl-glass .homepage-glass.bookmark-group {
        border: 0 !important;
        box-shadow: none !important;
      }

      html.webgl-glass .homepage-glass.service-card {
        border: 1px solid rgba(255, 255, 255, 0.16) !important;
        box-shadow: none !important;
      }

      html.webgl-glass .homepage-glass.service-card:hover {
        border-color: rgba(255, 255, 255, 0.26) !important;
        box-shadow: 0 10px 28px rgba(2, 8, 18, 0.22) !important;
      }

      #footer {
        display: none !important;
      }

      @media (max-width: 768px) {
        #information-widgets {
          margin: 14px 12px 6px !important;
          padding: 0 !important;
        }

        .widget-container {
          min-height: 42px !important;
          padding: 6px 10px !important;
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
