{
  config,
  LT,
  lib,
  ...
}:
let
  cfg = config.lantian.moviepilot;
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
    systemd.tmpfiles.settings.moviepilot."${cfg.dataDir}/.cloakbrowser"."d" = {
      mode = "0755";
      user = "root";
      group = "root";
    };

    virtualisation.oci-containers.containers.moviepilot = {
      image = "docker.io/jxxghp/moviepilot-v2:latest";
      autoStart = true;
      labels."io.containers.autoupdate" = "registry";
      ports = [
        "127.0.0.1:${LT.portStr.MoviePilot.Frontend}:3000"
      ];
      environment = {
        TZ = config.time.timeZone;
        PORT = "3001";
        NGINX_PORT = "3000";
        MOVIEPILOT_AUTO_UPDATE = "false";
        DB_TYPE = "sqlite";
        CACHE_BACKEND_TYPE = "cachetools";
      };
      volumes = [
        "${cfg.dataDir}:/config"
        "${cfg.dataDir}/.cloakbrowser:/moviepilot/.cloakbrowser"
        "/mnt/storage/downloads:/mnt/storage/downloads"
        "/mnt/storage/media-radarr:/mnt/storage/media-radarr"
        "/mnt/storage/media-sonarr:/mnt/storage/media-sonarr"
      ];
    };

    systemd.services.podman-moviepilot = {
      after = [
        "mnt-storage.mount"
        "network-online.target"
      ];
      requires = [ "mnt-storage.mount" ];
      unitConfig = {
        ConditionPathExists = "/nix/persistent/var/lib/media-apps/ready";
        RequiresMountsFor = [
          "/mnt/storage"
          cfg.dataDir
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
