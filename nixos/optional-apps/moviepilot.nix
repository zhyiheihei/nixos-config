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
      # 与 hosts/rock5c/media-apps.nix 的 mkForce 保持一致：v3 基线。
      # OidcAuth 官方尚无 v3 适配，OIDC 登录暂不可用（等 package.v3.json
      # 出现 oidcauth），本地密码登录不受影响；详见 oidc-app-integration.md。
      image = "docker.io/jxxghp/moviepilot-v3:latest";
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
        # Mount the whole NFS root as one bind.  Separate subdirectory binds
        # make the same NFS filesystem look like different devices inside the
        # container, which breaks hardlink-based library imports.
        "/mnt/storage:/mnt/storage"
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
      "moviepilot.${config.networking.hostName}.zhyi.xin" = {
        locations = {
          "/" = {
            proxyPass = "http://127.0.0.1:${LT.portStr.MoviePilot.Frontend}";
            proxyWebsockets = true;
            proxyNoTimeout = true;
          };
        };
        sslCertificate = "zerossl-${config.networking.hostName}.zhyi.xin";
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
