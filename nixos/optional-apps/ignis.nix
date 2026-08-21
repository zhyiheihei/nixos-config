{
  config,
  LT,
  lib,
  ...
}:
let
  cfg = config.lantian.ignis;
in
{
  options.lantian.ignis = {
    enable = lib.mkEnableOption "Ignis self-hosted web Obsidian";
    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/nix/persistent/var/lib/ignis";
      description = "Host directory for Ignis server data and the downloaded Obsidian app";
    };
    vaultDir = lib.mkOption {
      type = lib.types.str;
      default = "/mnt/storage/media/Notes";
      description = "Host directory mounted as the Ignis vault (the knowledge-chain Notes folder)";
    };
    uid = lib.mkOption {
      type = lib.types.int;
      default = 1000;
      description = "UID the container runs as, matching the vault directory owner";
    };
    gid = lib.mkOption {
      type = lib.types.int;
      default = 1000;
      description = "GID the container runs as, matching the vault directory owner";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.tmpfiles.settings.ignis."${cfg.dataDir}"."d" = {
      mode = "0755";
      user = "root";
      group = "root";
    };
    systemd.tmpfiles.settings.ignis."${cfg.dataDir}/data"."d" = {
      mode = "0755";
      user = toString cfg.uid;
      group = toString cfg.gid;
    };
    systemd.tmpfiles.settings.ignis."${cfg.dataDir}/obsidian-app"."d" = {
      mode = "0755";
      user = toString cfg.uid;
      group = toString cfg.gid;
    };

    virtualisation.oci-containers.containers.ignis = {
      image = "docker.io/nobbe/ignis:0.8.9";
      autoStart = true;
      labels."io.containers.autoupdate" = "registry";
      ports = [ "127.0.0.1:${LT.portStr.Ignis}:8080" ];
      environment = {
        TZ = config.time.timeZone;
        PUID = toString cfg.uid;
        PGID = toString cfg.gid;
        # The vault lives on the NFS-backed /mnt/storage share; coalesce rapid
        # writes so the Obsidian editor does not hammer the NAS with small writes.
        WRITE_COALESCE_MS = "500";
      };
      volumes = [
        "${cfg.dataDir}/data:/app/data"
        "${cfg.dataDir}/obsidian-app:/app/obsidian-app"
        # Mount the existing knowledge-chain Notes folder directly as the vault,
        # so Obsidian edits stay inside the Syncthing/Gitea distribution.
        "${cfg.vaultDir}:/vaults/Notes"
      ];
    };

    systemd.services.podman-ignis = {
      after = [
        "mnt-storage.mount"
        "network-online.target"
      ];
      requires = [ "mnt-storage.mount" ];
      unitConfig = {
        RequiresMountsFor = [
          "/mnt/storage"
          cfg.vaultDir
          cfg.dataDir
        ];
      };
    };

    lantian.nginxVhosts = {
      "ignis.${config.networking.hostName}.zhyi.xin" = {
        locations = {
          "/" = {
            proxyPass = "http://127.0.0.1:${LT.portStr.Ignis}";
            proxyWebsockets = true;
            proxyNoTimeout = true;
            # Ignis has no built-in auth; guard the vault behind the shared
            # oauth2-proxy (Dex SSO) like the other private web apps.
            enableOAuth = true;
          };
        };
        sslCertificate = "lets-encrypt-${config.networking.hostName}.zhyi.xin";
        noIndex.enable = true;
        accessibleBy = "private";
      };
      "ignis.localhost" = {
        listenHTTP.enable = true;
        listenHTTPS.enable = false;
        locations = {
          "/" = {
            proxyPass = "http://127.0.0.1:${LT.portStr.Ignis}";
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
