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
    # Bootstrap mirrors halo.nix: container + MySQL provisioning, and a
    # single oneshot (lsky-pro-setup) that drives the official install API
    # on a fresh data dir and applies the declarative rows afterwards.
    # Never pre-create /var/lib/lsky-pro/.env or installed.lock: the image
    # entrypoint decides "already installed" by the existence of .env, and
    # the auto-migrate path cannot boot on an empty DB (Laravel reads the
    # settings table before migrations run).
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

    systemd.tmpfiles.settings.lsky-pro = {
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

    # Provision the database/user the installer will fill in (halo.nix
    # pattern). The container connects from the podman subnet via the relay.
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
        CREATE DATABASE IF NOT EXISTS lsky CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
        CREATE USER IF NOT EXISTS 'lsky'@'10.88.%' IDENTIFIED BY '$escaped_password';
        ALTER USER 'lsky'@'10.88.%' IDENTIFIED BY '$escaped_password';
        GRANT ALL PRIVILEGES ON lsky.* TO 'lsky'@'10.88.%';
        FLUSH PRIVILEGES;
        SQL
      '';
    };

    # On a fresh data dir, drive the official install API so the app creates
    # its own schema, .env and admin account; then apply the declarative
    # rows the install API cannot set (S3 storage policy, site toggles).
    # Idempotent: skips both halves once the database is populated.
    systemd.services.lsky-pro-setup = {
      description = "Bootstrap and declaratively configure Lsky Pro";
      after = [
        "mysql.service"
        "podman-lsky-pro.service"
        "sops-install-secrets.service"
      ];
      requiredBy = [ "podman-lsky-pro.service" ];
      serviceConfig = LT.serviceHarden // {
        Type = "oneshot";
        RemainAfterExit = true;
        Restart = "on-failure";
        RestartSec = "10s";
        TimeoutStartSec = "15min";
      };
      path = [
        config.services.mysql.package
        pkgs.curl
        pkgs.jq
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

          tables=$(mysql --protocol=socket --user=root -N -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'lsky'")
          if [ "$tables" = 0 ]; then
            # Wait for the container's install endpoint to come up.
            for i in $(seq 1 60); do
              curl -sf -m 3 http://127.0.0.1:13835/install >/dev/null && break
              sleep 5
            done

            curl -sf -X POST http://127.0.0.1:13835/install/verify \
              -H 'Content-Type: application/json' -H 'Accept: application/json' \
              -d "$(jq -cn --arg k "$license_key" '{license_key:$k,app_url:"https://pic.zhyi.xin"}')"

            out=$(curl -sfN -X POST http://127.0.0.1:13835/install \
              -H 'Content-Type: application/json' -H 'Accept: text/plain' \
              -d "$(jq -cn \
                --arg k "$license_key" --arg p "$admin_password" \
                '{app_name:"Zhyi Image Host",db_connection:"mysql",db_host:"10.88.0.1",db_port:"3306",db_database:"lsky",db_username:"lsky",db_password:$p,admin_username:"zhyi",admin_email:"zhyi@zhyi.cc",admin_password:$p}')")
            echo "$out" | tail -20
            echo "$out" | grep -q "程序安装成功" || {
              echo "install API did not report success" >&2
              exit 1
            }
          fi

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

          # --- site toggles (only keys declared here are owned by the
          # seed; everything else stays whatever the installer created)
          upsert_setting() {
            {
              echo "DELETE FROM settings WHERE \`group\` = '$1' AND name = '$2';"
              echo "INSERT INTO settings (\`group\`, name, locked, payload, created_at, updated_at)"
              echo "  VALUES ('$1', '$2', 0, '$3', NOW(), NOW());"
            } | ${mysqlCmd}
          }
          upsert_setting app timezone '"Asia/Shanghai"'
          upsert_setting app locale '"zh_CN"'
          upsert_setting app enable_site true
          upsert_setting app enable_registration false
          upsert_setting app guest_upload false
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
  };
}
