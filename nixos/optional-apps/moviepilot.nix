{
  config,
  inputs,
  LT,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.lantian.moviepilot;
  moviepilotPkg = inputs.zhyi-packages.packages.${pkgs.system}.moviepilot;
  proxy = "socks5://${LT.hosts.router.interconnect.IPv4}:${LT.portStr.V2Ray.SocksClient}";
  proxyBypass = "localhost,127.0.0.1,::1,192.168.0.0/16,198.18.0.0/15,.zhyi.cc,.zhyi.xin,.m-team.cc,.m-team.io,api.m-team.io";
  proxyEnvironment = {
    HTTP_PROXY = proxy;
    HTTPS_PROXY = proxy;
    NO_PROXY = proxyBypass;
    http_proxy = proxy;
    https_proxy = proxy;
    no_proxy = proxyBypass;
  };
  moviepilotRunner = pkgs.writeShellScript "moviepilot-runner" ''
    set -u
    ${moviepilotPkg}/bin/moviepilot start --timeout 120 || exit 1
    while :; do
      sleep 30
      if ! ${pkgs.curl}/bin/curl -fsS \
        "http://127.0.0.1:${LT.portStr.MoviePilot.Backend}/api/v1/system/global?token=moviepilot" \
        >/dev/null 2>&1; then
        ${moviepilotPkg}/bin/moviepilot restart --start-timeout 120 --stop-timeout 30 \
          >/dev/null 2>&1 || ${moviepilotPkg}/bin/moviepilot start --timeout 120 \
          >/dev/null 2>&1 || true
      fi
    done
  '';
in
{
  options.lantian.moviepilot = {
    enable = lib.mkEnableOption "MoviePilot media automation";
    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/nix/persistent/var/lib/moviepilot";
      description = "Host directory for MoviePilot configuration and SQLite data";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.tmpfiles.settings.moviepilot."${cfg.dataDir}"."d" = {
      mode = "0750";
      user = "zhyi";
      group = "users";
    };

    systemd.services.moviepilot = {
      description = "MoviePilot media automation";
      wantedBy = [ "multi-user.target" ];
      after = [
        "mnt-storage.mount"
        "network.target"
      ];
      requires = [ "mnt-storage.mount" ];
      unitConfig = {
        ConditionPathExists = "/nix/persistent/var/lib/media-apps/ready";
        RequiresMountsFor = [
          "/mnt/storage"
          cfg.dataDir
        ];
      };
      environment =
        proxyEnvironment
        // {
          HOME = cfg.dataDir;
          CONFIG_DIR = cfg.dataDir;
          TZ = config.time.timeZone;
          PORT = LT.portStr.MoviePilot.Backend;
          NGINX_PORT = LT.portStr.MoviePilot.Frontend;
          MOVIEPILOT_AUTO_UPDATE = "false";
          DB_TYPE = "sqlite";
          CACHE_BACKEND_TYPE = "cachetools";
        };
      path = [
        pkgs.curl
        pkgs.ffmpeg
        pkgs.git
        pkgs.jq
        pkgs.nodejs
        pkgs.openssh
        pkgs.rclone
        pkgs.rsync
        pkgs.unzip
      ];
      serviceConfig =
        LT.serviceHarden
        // {
          Type = "simple";
          User = "zhyi";
          Group = "users";
          ExecStart = moviepilotRunner;
          Restart = "on-failure";
          RestartSec = "10";
          PrivateDevices = false;
          PrivateTmp = false;
          ProtectHome = false;
          ProtectSystem = false;
          RestrictNamespaces = false;
          SystemCallFilter = [ ];
          MemoryDenyWriteExecute = false;
          NoNewPrivileges = false;
          ReadWritePaths = [
            cfg.dataDir
            "/mnt/storage/downloads"
            "/mnt/storage/.downloads-auto"
            "/mnt/storage/.downloads-qb"
            "/mnt/storage/.downloads-qb-pt"
            "/mnt/storage/.downloads-qb-seedbox"
            "/mnt/storage/media-radarr"
            "/mnt/storage/media-sonarr"
          ];
        };
    };

    lantian.nginxVhosts = {
      "moviepilot.${config.networking.hostName}.zhyi.cc" = {
        locations = {
          "/" = {
            proxyPass = "http://127.0.0.1:${LT.portStr.MoviePilot.Frontend}";
            proxyWebsockets = true;
            proxyNoTimeout = true;
          };
        };
        sslCertificate = "zerossl-${config.networking.hostName}.zhyi.cc";
        noIndex.enable = true;
        accessibleBy = "private";
      };
      "moviepilot.localhost" = {
        listenHTTP.enable = true;
        listenHTTPS.enable = false;
        locations = {
          "/" = {
            proxyPass = "http://127.0.0.1:${LT.portStr.MoviePilot.Frontend}";
            proxyWebsockets = true;
            proxyNoTimeout = true;
          };
        };
        noIndex.enable = true;
        accessibleBy = "localhost";
      };
    };
  };
}
