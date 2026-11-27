{
  config,
  lib,
  pkgs,
  LT,
  ...
}:
let
  cfg = config.lantian.pterodactylWings;
  domain = "zhyi.xin";
in
{
  options.lantian.pterodactylWings = {
    enable = lib.mkEnableOption "Pterodactyl Wings game server node";

    storage = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/pterodactyl";
      description = "Persistent state directory for Wings and its server volumes";
    };

    panelDomain = lib.mkOption {
      type = lib.types.str;
      default = "panel.${domain}";
      description = "Domain the Wings container resolves to the panel";
    };

    panelAddress = lib.mkOption {
      type = lib.types.str;
      default = "10.88.0.1";
      description = "Address the Wings container maps panelDomain to; the podman gateway when the panel runs on the same host";
    };

    nodeDomain = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Public domain of the Wings API; served through nginx with TLS when set";
    };

    apiBind = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Host address the Wings API is published on";
    };

    apiPort = lib.mkOption {
      type = lib.types.int;
      default = LT.port.Pterodactyl.Wings;
      description = "Wings API port";
    };

    sftpPort = lib.mkOption {
      type = lib.types.int;
      default = LT.port.Pterodactyl.SFTP;
      description = "Wings SFTP port";
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

    prefetchImage = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Container image to keep prefetched for the servers running on this node";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = lib.optional (cfg.nodeDomain != null) {
      assertion = builtins.elem cfg.nodeDomain LT.constants.publicSites;
      message = "${cfg.nodeDomain} must be listed in helpers/constants/public-sites.nix";
    };

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
            | .api.port = ${toString cfg.apiPort}
            | .api.ssl.enabled = false
            | .system.sftp.bind_port = ${toString cfg.sftpPort}
            | .system.data = "${cfg.storage}/volumes"
            | .ignore_panel_config_updates = true
            | .docker.log_config.type = ""
            | .docker.network.dns = ${builtins.toJSON cfg.containerDns}
          ' ${cfg.storage}/wings/config.yml
        '';
      };

      # Wings refuses to start without the node configuration written by the
      # panel, so keep the unit idle until the first deployment is bootstrapped.
      "podman-pterodactyl-wings".unitConfig.ConditionPathExists = "${cfg.storage}/wings/config.yml";
    }
    // lib.optionalAttrs (cfg.prefetchImage != null) {
      pterodactyl-prefetch-image = {
        description = "预拉 Pterodactyl 实例镜像（${cfg.prefetchImage}）";
        wants = [ "network-online.target" ];
        after = [
          "network-online.target"
          "sops-install-secrets.service"
        ];
        environment = LT.proxyEnvironment;
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${pkgs.podman}/bin/podman pull ${cfg.prefetchImage}";
          # 拉不动就下一轮再试，别把 systemd 状态搞成 failed 淹没真正的告警
          SuccessExitStatus = "0 125";
          TimeoutStartSec = "30min";
        };
      };
    };

    systemd.timers = lib.mkIf (cfg.prefetchImage != null) {
      pterodactyl-prefetch-image = {
        description = "定时预拉 Pterodactyl 实例镜像";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnBootSec = "5min";
          OnUnitActiveSec = "30min";
          RandomizedDelaySec = "120";
        };
      };
    };

    systemd.tmpfiles.settings.pterodactyl = {
      "${cfg.storage}"."d" = {
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
      "/run/wings"."d" = {
        mode = "0700";
        user = "root";
        group = "root";
      };
      "/var/log/pterodactyl"."d" = {
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

    virtualisation.oci-containers.containers.pterodactyl-wings = {
      image = "ghcr.io/pterodactyl/wings:latest";
      labels."io.containers.autoupdate" = "registry";
      extraOptions = [ "--add-host=${cfg.panelDomain}:${cfg.panelAddress}" ];
      environment = {
        TZ = config.time.timeZone;
        DOCKER_HOST = "unix:///var/run/docker.sock";
        SSL_CERT_FILE = "/etc/ssl/certs/ca-certificates.crt";
      };
      ports = [
        "${cfg.apiBind}:${toString cfg.apiPort}:${toString cfg.apiPort}"
        "${toString cfg.sftpPort}:${toString cfg.sftpPort}"
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

    lantian.nginxVhosts = lib.mkIf (cfg.nodeDomain != null) {
      "${cfg.nodeDomain}" = {
        locations."/" = {
          proxyPass = "http://127.0.0.1:${toString cfg.apiPort}";
          proxyWebsockets = true;
          proxyNoTimeout = true;
        };

        sslCertificate = "lets-encrypt-${domain}";
        accessibleBy = "public";
        noIndex.enable = true;
      };
    };
  };
}
