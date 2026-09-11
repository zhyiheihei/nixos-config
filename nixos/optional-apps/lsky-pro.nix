{
  config,
  lib,
  LT,
  ...
}:
let
  cfg = config.lantian.lskyPro;
in
{
  options.lantian.lskyPro = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
  };

  imports = [ ./mysql.nix ];

  config = lib.mkIf cfg.enable {
    # Official Docker image (FrankenPHP + libvips, bundled queue/scheduler).
    # First visit to the web UI runs the graphical installer; the host MySQL
    # (MariaDB) is pre-provisioned below so the installer can use it directly.
    # Host networking (same pattern as halo.nix): the container reaches the
    # loopback-bound MySQL directly, and its own listener lands on host
    # loopback at the registered port (env overrides the in-container listen
    # port from 8000).
    virtualisation.oci-containers.containers.lsky-pro = {
      image = "docker.io/0xxb/lsky-pro:latest";
      labels."io.containers.autoupdate" = "registry";
      volumes = [
        "/var/lib/lsky-pro:/app/storage/app"
        "/var/lib/lsky-pro/themes:/app/themes"
      ];
      extraOptions = [ "--network=host" ];
      environment = {
        PORT = LT.portStr.LskyPro;
      };
    };

    systemd.tmpfiles.settings = {
      lsky-pro = {
        "/var/lib/lsky-pro"."d" = {
          mode = "755";
          user = "root";
          group = "root";
        };
        "/var/lib/lsky-pro/themes"."d" = {
          mode = "755";
          user = "root";
          group = "root";
        };
      };
    };

    # Write the installer-facing .env directly into the persistent data dir:
    # the container mounts /var/lib/lsky-pro as /app/storage/app and reads
    # .env from there. DB password is the fleet-wide default-pw secret;
    # APP_KEY/APP_URL stay for the installer to fill (it only writes keys
    # that are still empty/placeholder).
    sops.templates.lsky-pro-env = {
      content = ''
        DB_CONNECTION=mysql
        DB_HOST=127.0.0.1
        DB_PORT=3306
        DB_DATABASE=lsky
        DB_USERNAME=lsky
        DB_PASSWORD=${config.sops.placeholder.default-pw}
      '';
      # Owned by root: rendered at /run/secrets/rendered, copied into place
      # by the preStart below.
      mode = "0400";
    };

    systemd.services.podman-lsky-pro = {
      preStart = lib.mkAfter ''
        mkdir -p /var/lib/lsky-pro
        # Merge DB settings into the container-generated .env: keep any
        # existing non-DB lines (APP_KEY etc.) from the installer, replace
        # or append our DB_* directives.
        envFile=/var/lib/lsky-pro/.env
        touch "$envFile"
        for key in DB_CONNECTION DB_HOST DB_PORT DB_DATABASE DB_USERNAME DB_PASSWORD; do
          sed -i "/^$key=/d" "$envFile"
        done
        sed -i "/^# DB_/d" "$envFile"
        cat ${config.sops.templates.lsky-pro-env.path} >> "$envFile"
      '';
    };

    # Public entry: pic.zhyi.xin, wildcard cert synced from greencloud.
    lantian.nginxVhosts."pic.zhyi.xin" = {
      locations."/" = {
        proxyPass = "http://127.0.0.1:${LT.portStr.LskyPro}";
        proxyWebsockets = true;
        proxyNoTimeout = true;
      };
      sslCertificate = "lets-encrypt-zhyi.xin";
      noIndex.enable = true;
    };

    # Provision the MySQL database/user up front; the web installer just
    # fills in these values. mysql.nix binds MariaDB to 127.0.0.1, which
    # matches the host-network container.
    services.mysql.ensureDatabases = [ "lsky" ];
    services.mysql.ensureUsers = [
      {
        name = "lsky";
        ensurePermissions = {
          "lsky.*" = "ALL PRIVILEGES";
        };
      }
    ];
  };
}
