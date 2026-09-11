{
  config,
  pkgs,
  lib,
  inputs,
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
    # Fully declarative bootstrap, no web installer: the data dir ships an
    # installed.lock (image entrypoint then auto-runs migrations on boot),
    # APP_KEY is generated on first preStart, and all runtime rows (site
    # settings, S3 storage policy, admin account) are seeded idempotently
    # by lsky-pro-seed.service below.
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
        # Image entrypoint skips the web installer and auto-migrates when
        # this lock file exists.
        "/var/lib/lsky-pro/installed.lock"."f" = { };
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

    sops.secrets = {
      lsky-vaults3-access-key = {
        sopsFile = inputs.secrets + "/lsky.yaml";
        mode = "0400";
      };
      lsky-vaults3-secret-key = {
        sopsFile = inputs.secrets + "/lsky.yaml";
        mode = "0400";
      };
      lsky-license-key = {
        sopsFile = inputs.secrets + "/lsky.yaml";
        mode = "0400";
      };
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
        # Fresh-deployment path (no web installer): Laravel refuses to boot
        # without APP_KEY, so generate one into .env on first run.
        if ! grep -q '^APP_KEY=.' "$envFile"; then
          sed -i "/^APP_KEY=/d" "$envFile"
          echo "APP_KEY=base64:$(${pkgs.openssl}/bin/openssl rand -base64 32)" >> "$envFile"
        fi
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

    # Idempotent declarative seeding of all runtime state the web installer
    # would otherwise create: site settings, the S3 storage policy (dedicated
    # VaultS3 IAM key from sops), the admin account (bcrypt of fleet
    # default-pw) and its storage binding. Lsky Pro+ is closed-source, so
    # rows are written straight to MariaDB (settings payload is JSON per its
    # Laravel cast; users.password is PHP bcrypt).
    systemd.services.lsky-pro-seed = {
      description = "Seed Lsky Pro settings/storage/admin declaratively";
      after = [
        "mysql.service"
        "podman-lsky-pro.service"
        "sops-install-secrets.service"
      ];
      requires = [ "podman-lsky-pro.service" ];
      requiredBy = [ "podman-lsky-pro.service" ];
      # Tables may not exist yet on a fresh data dir (migrations run inside
      # the container entrypoint); retry until they do.
      serviceConfig = LT.serviceHarden // {
        Type = "oneshot";
        RemainAfterExit = true;
        Restart = "on-failure";
        RestartSec = "10s";
      };
      path = [
        config.services.mysql.package
        pkgs.jq
        pkgs.php
      ];
      script =
        let
          mysqlCmd = "mysql --protocol=socket --user=root lsky";
        in
        ''
          access_key=$(<${config.sops.secrets.lsky-vaults3-access-key.path})
          secret_key=$(<${config.sops.secrets.lsky-vaults3-secret-key.path})
          license_key=$(<${config.sops.secrets.lsky-license-key.path})
          admin_password=$(<${config.sops.secrets.default-pw.path})

          esc() { printf %s "$1" | sed -e 's/\\/\\\\/g' -e "s/'/\\\\'/g"; }
          esc_json() { printf %s "$1" | sed -e 's/\\/\\\\\\/g' -e "s/'/\\\\'/g"; }

          # --- storage policy: VaultS3 on greencloud-jp, path-style, no
          # prefix (Lsky builds the public URL from prefix but stores the
          # object without it, so any non-empty prefix breaks links)
          s3_options=$(jq -cn --arg a "$access_key" --arg s "$secret_key" \
            '{endpoint:"https://s3.zhyi.xin",access_key_id:$a,secret_access_key:$s,region:"us-east-1",bucket:"lsky",use_path_style_endpoint:true,public_url:"https://s3.zhyi.xin/lsky",naming_rule:"{Ymd}/{md5}"}')
          ${mysqlCmd} <<SQL
          INSERT INTO storages (name, intro, prefix, provider, options, created_at, updated_at)
            SELECT 'VaultS3', 'greencloud-jp VaultS3', ''', 's3', '$(esc_json "$s3_options")', NOW(), NOW()
            WHERE NOT EXISTS (SELECT 1 FROM storages WHERE name = 'VaultS3' AND deleted_at IS NULL);
          UPDATE storages SET intro = 'greencloud-jp VaultS3', prefix = ''', provider = 's3', options = '$(esc_json "$s3_options")', updated_at = NOW()
            WHERE name = 'VaultS3' AND deleted_at IS NULL;
          INSERT INTO group_storage (group_id, storage_id, sort)
            SELECT g.id, s.id, 1 FROM \`groups\` g, storages s
            WHERE g.is_default = 1 AND s.name = 'VaultS3' AND s.deleted_at IS NULL
              AND NOT EXISTS (
                SELECT 1 FROM group_storage gs
                WHERE gs.group_id = g.id AND gs.storage_id = s.id
              );
          SQL

          # --- site settings (only keys declared here are owned by the
          # seed; everything else stays whatever the app created)
          upsert_setting() {
            {
              echo "DELETE FROM settings WHERE \`group\` = '$1' AND name = '$2';"
              echo "INSERT INTO settings (\`group\`, name, locked, payload, created_at, updated_at)"
              echo "  VALUES ('$1', '$2', 0, '$3', NOW(), NOW());"
            } | ${mysqlCmd}
          }
          upsert_setting app name '"Zhyi Image Host"'
          upsert_setting app url '"https://pic.zhyi.xin"'
          upsert_setting app license_key "'$(esc "$license_key")'"
          upsert_setting app timezone '"Asia/Shanghai"'
          upsert_setting app locale '"zh_CN"'
          upsert_setting app currency '"CNY"'
          upsert_setting app enable_site true
          upsert_setting app enable_registration false
          upsert_setting app guest_upload false

          # --- initial admin: username zhyi, password = fleet default-pw
          admin_hash=$(php -r 'echo password_hash($argv[1], PASSWORD_BCRYPT);' "$admin_password")
          admin_id=$(${mysqlCmd} -N -e "SELECT id FROM users WHERE username = 'zhyi' LIMIT 1")
          if [ -z "$admin_id" ]; then
            {
              echo "INSERT INTO users (avatar, name, username, email, password, location, url, company, company_title, tagline, bio, is_admin, status, email_verified_at, created_at, updated_at)"
              echo "  VALUES (''', 'zhyi', 'zhyi', 'zhyi@zhyi.cc', '$(esc "$admin_hash")', ''', ''', ''', ''', ''', ''', 1, 'normal', NOW(), NOW(), NOW());"
            } | ${mysqlCmd}
          else
            {
              echo "UPDATE users SET password = '$(esc "$admin_hash")', email = 'zhyi@zhyi.cc', is_admin = 1, status = 'normal',"
              echo "  email_verified_at = COALESCE(email_verified_at, NOW()), updated_at = NOW() WHERE id = $admin_id;"
            } | ${mysqlCmd}
          fi
        '';
    };
  };
}
