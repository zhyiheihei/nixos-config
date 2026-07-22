{
  LT,
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
{
  imports = [ ./mysql.nix ];

  sops.secrets.halo-mysql-password = {
    sopsFile = inputs.secrets + "/common/personal-apps.yaml";
    key = "HALO_MYSQL_PASSWORD";
  };

  sops.templates.halo-env.content = ''
    SPRING_R2DBC_PASSWORD=${config.sops.placeholder.halo-mysql-password}
  '';

  services.mysql = {
    ensureDatabases = [ "halo" ];
    ensureUsers = [
      {
        name = "halo";
        ensurePermissions."halo.*" = "ALL PRIVILEGES";
      }
    ];
    # MySQL 专用于 Halo，大幅降低内存占用（cnvm 2GB 总内存）
    settings.mysqld = {
      max_connections = lib.mkForce 20;
      innodb_buffer_pool_size = lib.mkForce "32M";
      innodb_log_buffer_size = lib.mkForce "4M";
      key_buffer_size = lib.mkForce "4M";
      table_open_cache = lib.mkForce 64;
      thread_cache_size = lib.mkForce 4;
      sort_buffer_size = lib.mkForce "1M";
      read_buffer_size = lib.mkForce "1M";
      tmp_table_size = lib.mkForce "8M";
      max_heap_table_size = lib.mkForce "8M";
    };
  };

  systemd.services.halo-mysql-password = {
    after = [ "mysql.service" "sops-install-secrets.service" ];
    requires = [ "mysql.service" ];
    before = [ "podman-halo.service" ];
    requiredBy = [ "podman-halo.service" ];
    path = [ config.services.mysql.package pkgs.gnused ];
    serviceConfig.Type = "oneshot";
    script = ''
      password=$(<${config.sops.secrets.halo-mysql-password.path})
      escaped_password=$(printf %s "$password" | sed -e 's/\\/\\\\/g' -e "s/'/\\\\'/g")
      mysql --protocol=socket --user=root <<SQL
      CREATE DATABASE IF NOT EXISTS halo;
      CREATE USER IF NOT EXISTS 'halo'@'localhost' IDENTIFIED BY '$escaped_password';
      ALTER USER 'halo'@'localhost' IDENTIFIED BY '$escaped_password';
      GRANT ALL PRIVILEGES ON halo.* TO 'halo'@'localhost';
      FLUSH PRIVILEGES;
      SQL
    '';
  };

  virtualisation.oci-containers.containers.halo = {
    extraOptions = [ "--network=host" ];
    image = "docker.io/halohub/halo-pro:2.25.4";
    labels."io.containers.autoupdate" = "registry";
    volumes = [ "/var/lib/halo:/root/.halo2" ];
    environment = {
      HALO_EXTERNAL_URL = "https://zhyi.xin";
      SERVER_ADDRESS = "127.0.0.1";
      SERVER_PORT = LT.portStr.Halo;
      SPRING_R2DBC_URL = "r2dbc:pool:mysql://127.0.0.1:3306/halo";
      SPRING_R2DBC_USERNAME = "halo";
      SPRING_SQL_INIT_PLATFORM = "mysql";
      TZ = config.time.timeZone;
    };
    environmentFiles = [ config.sops.templates.halo-env.path ];
  };

  systemd.tmpfiles.settings.halo."/var/lib/halo"."d" = {
    mode = "0755";
    user = "root";
    group = "root";
  };

  lantian.nginxVhosts = {
    "zhyi.xin" = {
      root = lib.mkForce null;
      locations = {
        "/" = lib.mkForce {
          proxyPass = "http://127.0.0.1:${LT.portStr.Halo}";
          proxyWebsockets = true;
          extraConfig = ''
            proxy_set_header Accept-Encoding "";
            sub_filter_once on;
            sub_filter '</head>' '<script defer data-domain="zhyi.xin" data-api="https://stats.zhyi.xin/api/event" src="https://stats.zhyi.xin/js/script.js"></script></head>';
          '';
        };
      };
    };
    "halo.${config.networking.hostName}.zhyi.cc" = {
      locations."/" = {
        proxyPass = "http://127.0.0.1:${LT.portStr.Halo}";
        proxyWebsockets = true;
        enableOAuth = true;
      };
      accessibleBy = "private";
      sslCertificate = "lets-encrypt-${config.networking.hostName}.zhyi.cc";
      noIndex.enable = true;
    };
    "halo.localhost" = {
      listenHTTP.enable = true;
      listenHTTPS.enable = false;
      locations."/" = {
        proxyPass = "http://127.0.0.1:${LT.portStr.Halo}";
        proxyWebsockets = true;
      };
      accessibleBy = "localhost";
      noIndex.enable = true;
    };
  };
}
