{
  config,
  LT,
  lib,
  ...
}:
let
  cfg = config.lantian.chinesesubfinder;
in
{
  options.lantian.chinesesubfinder = {
    enable = lib.mkEnableOption "ChineseSubFinder subtitle downloader for the media library";
    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/nix/persistent/var/lib/chinesesubfinder";
      description = "Host directory for ChineseSubFinder configuration";
    };
  };

  config = lib.mkIf cfg.enable {
    # ChineseSubFinder runs as uid 1026 (matches the NFS media library owner)
    # with PERMS=false, so the config dir must already be writable by it.
    systemd.tmpfiles.settings.chinesesubfinder."${cfg.dataDir}/config"."d" = {
      mode = "0750";
      user = "1026";
      group = "users";
    };

    virtualisation.oci-containers.containers.chinesesubfinder = {
      image = "docker.io/allanpk716/chinesesubfinder:latest";
      autoStart = true;
      labels."io.containers.autoupdate" = "registry";
      ports = [
        "127.0.0.1:${LT.portStr.ChineseSubFinder}:19035"
      ];
      environment = {
        TZ = config.time.timeZone;
        PUID = "1026";
        PGID = "100";
        UMASK = "022";
        # Keep existing file ownership; the NFS media tree is already owned
        # by uid 1026.
        PERMS = "false";
      };
      volumes = [
        "${cfg.dataDir}/config:/config"
        "/mnt/storage/media-sonarr:/media/media-sonarr"
        "/mnt/storage/media-radarr:/media/media-radarr"
      ];
    };

    systemd.services.podman-chinesesubfinder = {
      after = [
        "mnt-storage.mount"
        "network-online.target"
      ];
      requires = [ "mnt-storage.mount" ];
      unitConfig = {
        ConditionPathExists = "/nix/persistent/var/lib/media-apps/ready";
        RequiresMountsFor = [
          "/mnt/storage"
          "${cfg.dataDir}/config"
        ];
      };
    };
  };
}
