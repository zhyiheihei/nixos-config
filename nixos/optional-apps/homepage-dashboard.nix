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

    customCSS = ''      :root {
        --dashboard-ink: rgba(7, 10, 14, 0.96);
        --dashboard-panel: rgba(16, 20, 25, 0.97);
        --dashboard-line: rgba(255, 255, 255, 0.14);
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
        /* 背景交给 settings.background（随机壁纸 API），保持清晰 */
      }

      #background {
        opacity: 1 !important;
        background-position: center !important;
        background-size: cover !important;
        filter: saturate(1.06) contrast(1.04);
      }

      #page_wrapper::before {
        content: "";
        position: fixed;
        inset: 0;
        z-index: 1;
        pointer-events: none;
        background:
          linear-gradient(180deg, rgba(4, 7, 11, 0.2), rgba(4, 7, 11, 0.48) 78%),
          linear-gradient(90deg, rgba(4, 7, 11, 0.16), transparent 30%, transparent 70%, rgba(4, 7, 11, 0.16));
      }

      #inner_wrapper {
        width: min(100%, 1600px);
        padding-bottom: 32px;
      }

      #information-widgets {
        margin: 28px 32px 8px !important;
        padding: 8px !important;
        /* iOS 液态玻璃 */
        border: 1px solid rgba(255, 255, 255, 0.14) !important;
        border-radius: 22px !important;
        background: linear-gradient(180deg, rgba(255, 255, 255, 0.10), rgba(255, 255, 255, 0.04)) !important;
        backdrop-filter: blur(12px) saturate(150%) !important;
        -webkit-backdrop-filter: blur(12px) saturate(150%) !important;
        box-shadow:
          inset 0 1px 0 rgba(255, 255, 255, 0.14),
          0 8px 24px rgba(0, 0, 0, 0.22);
      }

      .widget-container {
        display: flex;
        align-items: center;
        justify-content: center;
        min-height: 58px;
        margin: 4px;
        padding: 8px 12px;
        border: 1px solid rgba(255, 255, 255, 0.12);
        border-radius: 16px;
        background: linear-gradient(180deg, rgba(255, 255, 255, 0.10), rgba(255, 255, 255, 0.04));
        backdrop-filter: blur(10px) saturate(150%);
        -webkit-backdrop-filter: blur(10px) saturate(150%);
        box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.14);
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
        padding: 10px 12px !important;
        overflow: hidden;
        /* iOS 液态玻璃卡片：顶部高光 + 低模糊 + 大圆角 */
        border: 1px solid rgba(255, 255, 255, 0.16) !important;
        border-radius: 22px !important;
        background: linear-gradient(180deg, rgba(255, 255, 255, 0.12), rgba(255, 255, 255, 0.05)) !important;
        backdrop-filter: blur(12px) saturate(150%) !important;
        -webkit-backdrop-filter: blur(12px) saturate(150%) !important;
        box-shadow:
          inset 0 1px 0 rgba(255, 255, 255, 0.18),
          0 8px 24px rgba(0, 0, 0, 0.22) !important;
        transition: transform 160ms ease, border-color 160ms ease, box-shadow 160ms ease, background 160ms ease !important;
      }

      .service-card:hover {
        transform: translateY(-2px);
        background: linear-gradient(180deg, rgba(255, 255, 255, 0.16), rgba(255, 255, 255, 0.08)) !important;
        border-color: rgba(255, 255, 255, 0.26) !important;
        box-shadow:
          inset 0 1px 0 rgba(255, 255, 255, 0.22),
          0 12px 32px rgba(0, 0, 0, 0.28) !important;
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

        #background {
          background-attachment: scroll !important;
        }
      }

      @media (prefers-reduced-motion: reduce) {
        .service-card {
          transition: none !important;
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
