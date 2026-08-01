{ lib, ... }:
let
  activationMarker = "/nix/persistent/var/lib/media-automation/ready";
  gatedServices = [
    "bazarr"
    "bitmagnet-dht"
    "bitmagnet-http"
    "bitmagnet-queue"
    "decluttarr"
    "flexget-runner"
    "iyuuplus"
    "jproxy"
    "peerbanhelper"
    "podman-byparr"
    "prometheus-exportarr-bazarr-exporter"
    "prometheus-exportarr-prowlarr-exporter"
    "prometheus-exportarr-radarr-exporter"
    "prometheus-exportarr-sonarr-exporter"
    "prowlarr"
    "qbittorrent"
    "qbittorrent-pt"
    "qbittorrent-pt-cleanup"
    "qbittorrent-seedbox"
    "radarr"
    "sonarr"
  ];
in
{
  imports = [ ../../nixos/optional-apps/media-automation.nix ];

  # The old and new download stacks must never write the same NFS paths at
  # once.  Deploy all packages, units, users, secrets and databases first, but
  # keep every writer stopped until the state transfer has completed.
  systemd.services = lib.genAttrs gatedServices (_: {
    partOf = [ "media-automation.target" ];
    unitConfig.ConditionPathExists = activationMarker;
  });
  systemd.timers = lib.genAttrs [
    "flexget-runner"
    "qbittorrent-pt-cleanup"
  ] (_: {
    partOf = [ "media-automation.target" ];
    unitConfig.ConditionPathExists = activationMarker;
  });

  systemd.targets.media-automation = {
    description = "OPI5P media download and automation stack";
    wants = map (name: "${name}.service") gatedServices ++ [
      "flexget-runner.timer"
      "qbittorrent-pt-cleanup.timer"
    ];
    after = [
      "mnt-storage.mount"
      "mysql.service"
      "postgresql.service"
    ];
  };

  systemd.tmpfiles.settings.media-automation = {
    "/nix/persistent/var/lib/media-automation".d = {
      mode = "0700";
      user = "root";
      group = "root";
    };
    # Bitmagnet's 16 GiB PostgreSQL database is write-heavy.  Set NOCOW while
    # the directory is still empty, before PostgreSQL initializes it on NVMe.
    "/nix/persistent/var/lib/postgresql" = {
      d = {
        mode = "0700";
        user = "postgres";
        group = "postgres";
      };
      h.argument = "+C";
    };
  };
}
