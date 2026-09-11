{
  config,
  pkgs,
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
    # Bridge networking with a published loopback port: the image's bundled
    # Caddyfile hardcodes listening on :8000 and does not read any port env,
    # and host networking would collide with bird-lgproxy-go on :8000.
    # MariaDB binds 127.0.0.1 only, so the relay unit below forwards the
    # podman0 gateway address to it for the container.
    virtualisation.oci-containers.containers.lsky-pro = {
      image = "docker.io/0xxb/lsky-pro:latest";
      labels."io.containers.autoupdate" = "registry";
      ports = [ "127.0.0.1:${LT.portStr.LskyPro}:8000" ];
      volumes = [
        "/var/lib/lsky-pro:/app/storage/app"
        "/var/lib/lsky-pro/themes:/app/themes"
      ];
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
        DB_HOST=10.88.0.1
        DB_PORT=3306
        DB_DATABASE=lsky
        DB_USERNAME=lsky
        DB_PASSWORD=${config.sops.placeholder.default-pw}
      '';
      # Owned by root: rendered at /run/secrets/rendered, copied into place
      # by the preStart below.
      mode = "0400";
    };

    # MariaDB (mysql.nix) binds 127.0.0.1 only; the container reaches it via
    # the podman0 gateway address. Forward 10.88.0.1:3306 -> 127.0.0.1:3306
    # on the host.
    systemd.services.lsky-pro-mysql-relay = {
      description = "Forward podman0 gateway :3306 to host MariaDB";
      wantedBy = [ "podman-lsky-pro.service" ];
      before = [ "podman-lsky-pro.service" ];
      after = [
        "mysql.service"
        "network-online.target"
      ];
      wants = [ "network-online.target" ];
      serviceConfig = LT.serviceHarden // {
        Type = "simple";
        Restart = "always";
        RestartSec = "5";
        ExecStart =
          let
            socatRelay = pkgs.writeShellScript "lsky-pro-mysql-relay" ''
              exec ${pkgs.socat}/bin/socat TCP-LISTEN:3306,bind=10.88.0.1,reuseaddr,fork TCP:127.0.0.1:3306
            '';
          in
          "${socatRelay}";
      };
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
    # fills in these values. mysql.nix binds MariaDB to 127.0.0.1; the relay
    # unit exposes it to the container via the podman0 gateway, so the lsky
    # user is granted access from the podman subnet (mirrors halo.nix's
    # dedicated-user pattern but with the shared default-pw secret).
    services.mysql.ensureDatabases = [ "lsky" ];
    services.mysql.ensureUsers = [
      {
        name = "lsky";
        ensurePermissions = {
          "lsky.*" = "ALL PRIVILEGES";
        };
      }
    ];

    systemd.services.lsky-pro-mysql-user = {
      description = "Grant lsky MySQL user access from the podman subnet";
      after = [
        "mysql.service"
        "sops-install-secrets.service"
      ];
      requires = [ "mysql.service" ];
      before = [ "podman-lsky-pro.service" ];
      requiredBy = [ "podman-lsky-pro.service" ];
      path = [ config.services.mysql.package ];
      serviceConfig.Type = "oneshot";
      script = ''
        password=$(<${config.sops.secrets.default-pw.path})
        escaped_password=$(printf %s "$password" | sed -e 's/\\/\\\\/g' -e "s/'/\\\\'/g")
        mysql --protocol=socket --user=root <<SQL
        CREATE USER IF NOT EXISTS 'lsky'@'10.88.%' IDENTIFIED BY '$escaped_password';
        ALTER USER 'lsky'@'10.88.%' IDENTIFIED BY '$escaped_password';
        GRANT ALL PRIVILEGES ON lsky.* TO 'lsky'@'10.88.%';
        FLUSH PRIVILEGES;
        SQL
      '';
    };
  };
}
