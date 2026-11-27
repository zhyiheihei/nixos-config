{
  config,
  lib,
  pkgs,
  LT,
  ...
}:
let
  cfg = config.lantian.pterodactyl;
  domain = "zhyi.xin";
  podmanGateway = "10.88.0.1";
  secretsDir = "${cfg.storage}/secrets";

  containers = [
    "pterodactyl-database"
    "pterodactyl-redis"
    "pterodactyl-panel"
    "pterodactyl-wings"
  ];
in
{
  options.lantian.pterodactyl = {
    enable = lib.mkEnableOption "Pterodactyl game server panel";

    storage = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/pterodactyl";
      description = "Persistent state directory for the panel, database, cache and Wings";
    };

    panelDomain = lib.mkOption {
      type = lib.types.str;
      default = "panel.${domain}";
      description = "Public domain of the panel frontend";
    };

    containerDns = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default =
        if config.networking.nameservers != [ ] then
          config.networking.nameservers
        else
          [
            "1.1.1.1"
            "1.0.0.1"
          ];
      description = "Resolvers handed to game containers; Wings' own default (1.1.1.1) may be unreachable";
    };

    nodeDomain = lib.mkOption {
      type = lib.types.str;
      default = "node.${domain}";
      description = "Public domain of the Wings API, reachable by the panel and by browsers";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = builtins.elem cfg.panelDomain LT.constants.publicSites;
        message = "${cfg.panelDomain} must be listed in helpers/constants/public-sites.nix";
      }
      {
        assertion = builtins.elem cfg.nodeDomain LT.constants.publicSites;
        message = "${cfg.nodeDomain} must be listed in helpers/constants/public-sites.nix";
      }
    ];

    # The database credentials are generated on the host instead of being
    # committed to the secrets repository.
    systemd.services = {
      # Wings creates its own network, which makes Podman give containers an
      # embedded resolver (aardvark-dns) instead of the host's resolv.conf.
      # Creating the network without the DNS plugin keeps game containers on
      # the system resolver, matching how other container workloads run here.
      pterodactyl-network = {
        description = "Create the Pterodactyl container network without the Podman DNS plugin";
        wantedBy = [ "multi-user.target" ];
        before = [ "podman-pterodactyl-wings.service" ];
        requiredBy = [ "podman-pterodactyl-wings.service" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        script = ''
          ${pkgs.podman}/bin/podman network exists pterodactyl_nw ||
            ${pkgs.podman}/bin/podman network create --disable-dns \
              --subnet 172.18.0.0/16 --gateway 172.18.0.1 pterodactyl_nw
        '';
      };

      pterodactyl-wings-config = {
        description = "Apply host overrides to the Pterodactyl Wings configuration";
        before = [ "podman-pterodactyl-wings.service" ];
        requiredBy = [ "podman-pterodactyl-wings.service" ];
        unitConfig.ConditionPathExists = "${cfg.storage}/wings/config.yml";
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        script = ''
          ${pkgs.yq-go}/bin/yq -i '
            .api.host = "0.0.0.0"
            | .api.port = ${toString LT.portStr.Pterodactyl.Wings}
            | .api.ssl.enabled = false
            | .system.sftp.bind_port = ${toString LT.portStr.Pterodactyl.SFTP}
            | .system.data = "${cfg.storage}/volumes"
            | .ignore_panel_config_updates = true
            | .docker.log_config.type = ""
            | .docker.network.dns = ${builtins.toJSON cfg.containerDns}
          ' ${cfg.storage}/wings/config.yml
        '';
      };

      pterodactyl-secrets = {
        description = "Generate Pterodactyl database credentials";
        wantedBy = [ "multi-user.target" ];
        before = [
          "podman-pterodactyl-database.service"
          "podman-pterodactyl-panel.service"
        ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          UMask = "0077";
        };
        script = ''
          set -eu
          for name in db-password db-root-password; do
            if [ ! -s "${secretsDir}/$name" ]; then
              ${pkgs.openssl}/bin/openssl rand -hex 32 > "${secretsDir}/$name"
            fi
          done
          printf 'DB_PASSWORD=%s\n' "$(cat "${secretsDir}/db-password")" > "${secretsDir}/panel.env"
          chmod 0600 "${secretsDir}"/*
        '';
      };
    }
    // lib.genAttrs (map (name: "podman-${name}") containers) (_: {
      after = [ "pterodactyl-secrets.service" ];
      requires = [ "pterodactyl-secrets.service" ];
    })
    // {
      # Wings refuses to start without the node configuration written by the
      # panel, so keep the unit idle until the first deployment is bootstrapped.
      "podman-pterodactyl-wings".unitConfig.ConditionPathExists = "${cfg.storage}/wings/config.yml";
    };

    systemd.tmpfiles.settings.pterodactyl = {
      "${cfg.storage}"."d" = {
        mode = "0700";
        user = "root";
        group = "root";
      };
      "${cfg.storage}/database"."d" = {
        mode = "0750";
        user = "999";
        group = "999";
      };
      "${cfg.storage}/redis"."d" = {
        mode = "0750";
        user = "999";
        group = "999";
      };
      "${cfg.storage}/panel"."d" = {
        mode = "0700";
        user = "root";
        group = "root";
      };
      "${cfg.storage}/panel/var"."d" = {
        mode = "0755";
        user = "root";
        group = "root";
      };
      "${cfg.storage}/panel/logs"."d" = {
        mode = "0755";
        user = "root";
        group = "root";
      };
      "${cfg.storage}/secrets"."d" = {
        mode = "0700";
        user = "root";
        group = "root";
      };
      "${cfg.storage}/wings"."d" = {
        mode = "0700";
        user = "root";
        group = "root";
      };
      "${cfg.storage}/volumes"."d" = {
        mode = "0700";
        user = "root";
        group = "root";
      };
      "${cfg.storage}/archives"."d" = {
        mode = "0700";
        user = "root";
        group = "root";
      };
      "${cfg.storage}/backups"."d" = {
        mode = "0700";
        user = "root";
        group = "root";
      };
      "/var/log/pterodactyl"."d" = {
        mode = "0700";
        user = "root";
        group = "root";
      };
      "/run/wings"."d" = {
        mode = "0700";
        user = "root";
        group = "root";
      };
      "/var/log/pterodactyl/install"."d" = {
        mode = "0700";
        user = "root";
        group = "root";
      };
    };

    virtualisation.oci-containers.containers = {
      pterodactyl-database = {
        image = "docker.io/library/mariadb:11";
        labels."io.containers.autoupdate" = "registry";
        environment = {
          MARIADB_DATABASE = "panel";
          MARIADB_USER = "pterodactyl";
          MARIADB_PASSWORD_FILE = "/run/secrets/db-password";
          MARIADB_ROOT_PASSWORD_FILE = "/run/secrets/db-root-password";
        };
        ports = [ "${podmanGateway}:${LT.portStr.Pterodactyl.Database}:3306" ];
        volumes = [
          "${cfg.storage}/database:/var/lib/mysql"
          "${secretsDir}/db-password:/run/secrets/db-password:ro"
          "${secretsDir}/db-root-password:/run/secrets/db-root-password:ro"
        ];
      };

      pterodactyl-redis = {
        image = "docker.io/library/redis:alpine";
        labels."io.containers.autoupdate" = "registry";
        ports = [ "${podmanGateway}:${LT.portStr.Pterodactyl.Redis}:6379" ];
        volumes = [ "${cfg.storage}/redis:/data" ];
      };

      pterodactyl-panel = {
        image = "ghcr.io/pterodactyl/panel:latest";
        labels."io.containers.autoupdate" = "registry";
        dependsOn = [
          "pterodactyl-database"
          "pterodactyl-redis"
        ];
        environment = {
          APP_URL = "https://${cfg.panelDomain}";
          APP_ENV = "production";
          APP_ENVIRONMENT_ONLY = "false";
          APP_DEBUG = "false";
          APP_LOCALE = "en";
          APP_TIMEZONE = config.time.timeZone;
          APP_SERVICE_AUTHOR = "noreply@${domain}";
          CACHE_DRIVER = "redis";
          SESSION_DRIVER = "redis";
          QUEUE_DRIVER = "redis";
          REDIS_HOST = podmanGateway;
          REDIS_PORT = LT.portStr.Pterodactyl.Redis;
          DB_HOST = podmanGateway;
          DB_PORT = LT.portStr.Pterodactyl.Database;
          DB_DATABASE = "panel";
          DB_USERNAME = "pterodactyl";
          HASHIDS_LENGTH = "8";
          # The panel defaults RECAPTCHA_ENABLED to true, which makes every login
          # call out to www.google.com before proceeding.
          RECAPTCHA_ENABLED = "false";
          TRUSTED_PROXIES = podmanGateway;
        };
        environmentFiles = [ "${secretsDir}/panel.env" ];
        extraOptions = [ "--add-host=${cfg.nodeDomain}:${podmanGateway}" ];
        ports = [ "127.0.0.1:${LT.portStr.Pterodactyl.Panel}:80" ];
        volumes = [
          "${cfg.storage}/panel/var:/app/var"
          "${cfg.storage}/panel/logs:/app/storage/logs"
        ];
      };

      pterodactyl-wings = {
        image = "ghcr.io/pterodactyl/wings:latest";
        labels."io.containers.autoupdate" = "registry";
        extraOptions = [ "--add-host=${cfg.panelDomain}:${podmanGateway}" ];
        environment = {
          TZ = config.time.timeZone;
          DOCKER_HOST = "unix:///var/run/docker.sock";
          SSL_CERT_FILE = "/etc/ssl/certs/ca-certificates.crt";
        };
        ports = [
          "127.0.0.1:${LT.portStr.Pterodactyl.Wings}:${LT.portStr.Pterodactyl.Wings}"
          "${LT.portStr.Pterodactyl.SFTP}:${LT.portStr.Pterodactyl.SFTP}"
        ];
        volumes = [
          "/run/podman/podman.sock:/var/run/docker.sock"
          "/run/wings:/run/wings"
          "/etc/localtime:/etc/localtime:ro"
          "/etc/ssl/certs/ca-certificates.crt:/etc/ssl/certs/ca-certificates.crt:ro"
          "${cfg.storage}/wings:/etc/pterodactyl"
          "${cfg.storage}/volumes:/var/lib/pterodactyl/volumes"
          "${cfg.storage}/archives:/var/lib/pterodactyl/archives"
          "${cfg.storage}/backups:/var/lib/pterodactyl/backups"
          "/var/log/pterodactyl:/var/log/pterodactyl"
        ];
      };
    };

    lantian.nginxVhosts."${cfg.panelDomain}" = {
      locations."/" = {
        proxyPass = "http://127.0.0.1:${LT.portStr.Pterodactyl.Panel}";
        proxyWebsockets = true;
        proxyNoTimeout = true;
      };

      sslCertificate = "lets-encrypt-${domain}";
      accessibleBy = "public";
      noIndex.enable = true;
    };

    lantian.nginxVhosts."${cfg.nodeDomain}" = {
      locations."/" = {
        proxyPass = "http://127.0.0.1:${LT.portStr.Pterodactyl.Wings}";
        proxyWebsockets = true;
        proxyNoTimeout = true;
      };

      sslCertificate = "lets-encrypt-${domain}";
      accessibleBy = "public";
      noIndex.enable = true;
    };
  };
}
