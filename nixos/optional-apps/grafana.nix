{
  pkgs,
  lib,
  config,
  inputs,
  LT,
  ...
}:
let
  prometheusDatasourceUid = "PBFA97CFB590B2093";

  dashboardDir = import ./grafana/dashboards.nix {
    inherit lib pkgs prometheusDatasourceUid;
  };

  mkPlugin =
    pluginSrc:
    (pkgs.grafanaPlugins.grafanaPlugin {
      pname = lib.removePrefix "grafana-" pluginSrc.pname;
      inherit (pluginSrc) version;
      zipHash = "placeholder";
    }).overrideAttrs
      (_old: {
        inherit (pluginSrc) src;
      });
in
{
  imports = [ ./mysql.nix ];

  sops.secrets.grafana-oauth = {
    sopsFile = inputs.secrets + "/grafana.yaml";
    owner = "grafana";
    group = "grafana";
  };

  services.grafana = {
    enable = true;

    declarativePlugins = with pkgs.grafanaPlugins; [
      grafana-clock-panel
      grafana-piechart-panel
      grafana-polystat-panel
      grafana-worldmap-panel

      (mkPlugin LT.sources.grafana-falconlogscale-datasource)
      (mkPlugin LT.sources.grafana-yesoreyeram-infinity-datasource)
    ];

    settings = {
      auth = {
        oauth_allow_insecure_email_lookup = "true";
      };
      users = {
        default_language = "zh-Hans";
        default_theme = "dark";
      };
      "auth.anonymous" = {
        enabled = "false";
      };
      "auth.generic_oauth" = {
        enabled = "true";
        name = "Dex";
        auto_login = "true";
        allow_sign_up = "true";
        scopes = "openid profile email groups offline_access";
        auth_url = "https://login.zhyi.xin/auth";
        token_url = "https://login.zhyi.xin/token";
        api_url = "https://login.zhyi.xin/userinfo";
        role_attribute_path = "contains(groups[*], 'admin') && 'Admin' || 'Viewer'";
      };
      database = {
        type = "mysql";
        host = "/run/mysqld/mysqld.sock";
        user = "grafana";
      };
      dashboards.default_home_dashboard_path = "${dashboardDir}/infrastructure-overview.json";
      log = {
        mode = "syslog";
        level = "error";
      };
      server = {
        protocol = "socket";
        domain = "dashboard.zhyi.cc";
        root_url = "https://dashboard.zhyi.cc/";
        socket = "/run/grafana/grafana.sock";
        socket_mode = "0777";
      };

      # Previously hardcoded in nixpkgs
      security.secret_key = "SW2YcwTIb9zpOOhoPsMm";

      smtp = with config.programs.msmtp.accounts.default; {
        enabled = true;
        inherit host user;
        password = "$__file{${config.sops.secrets.smtp-pass.path}}";
        from_address = from;
      };
    };

    provision = {
      enable = true;
      datasources.settings = {
        apiVersion = 1;
        prune = true;
        datasources = [
          {
            name = "Prometheus";
            uid = prometheusDatasourceUid;
            type = "prometheus";
            access = "proxy";
            url = "http://127.0.0.1:${LT.portStr.Prometheus.Daemon}";
            isDefault = true;
            editable = false;
            jsonData = {
              httpMethod = "POST";
              timeInterval = "15s";
            };
          }
        ];
      };
      dashboards.settings = {
        apiVersion = 1;
        providers = [
          {
            name = "zhyi-infrastructure";
            orgId = 1;
            folder = "基础设施";
            folderUid = "zhyi-infrastructure";
            type = "file";
            disableDeletion = false;
            editable = true;
            allowUiUpdates = true;
            updateIntervalSeconds = 30;
            options.path = dashboardDir;
          }
        ];
      };
    };
  };

  systemd.services.grafana.serviceConfig = {
    EnvironmentFile = config.sops.secrets.grafana-oauth.path;
    Restart = "on-failure";
    SystemCallFilter = [ "@chown" ];
  };

  users.users.nginx.extraGroups = [ "grafana" ];

  services.mysql = {
    ensureDatabases = [ "grafana" ];
    ensureUsers = [
      {
        name = "grafana";
        ensurePermissions = {
          "grafana.*" = "ALL PRIVILEGES";
        };
      }
    ];
  };

  lantian.nginxVhosts."dashboard.zhyi.cc" = {
    locations = {
      "/" = {
        proxyPass = "http://unix:${config.services.grafana.settings.server.socket}";
      };
      "/api/live/" = {
        proxyPass = "http://unix:${config.services.grafana.settings.server.socket}";
        proxyWebsockets = true;
      };
    };

    sslCertificate = "lets-encrypt-zhyi.cc";
    noIndex.enable = true;
  };
}
