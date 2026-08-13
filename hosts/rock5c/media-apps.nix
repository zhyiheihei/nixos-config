{
  lib,
  pkgs,
  ...
}:
let
  activationMarker = "/nix/persistent/var/lib/media-apps/ready";
  gatedServices = [
    "jellyfin"
    "sonarr"
    "radarr"
    "bazarr"
    "prowlarr"
    "decluttarr"
    "podman-handbrake"
    "prometheus-exportarr-sonarr-exporter"
    "prometheus-exportarr-radarr-exporter"
    "prometheus-exportarr-prowlarr-exporter"
    "prometheus-exportarr-bazarr-exporter"
  ];
  # These services are fully replaced by MoviePilot.  The units remain defined
  # in their modules for rollback, but must not run alongside the new chain.
  migratedServices = [
    "sonarr"
    "radarr"
    "bazarr"
    "prowlarr"
    "decluttarr"
    "prometheus-exportarr-sonarr-exporter"
    "prometheus-exportarr-radarr-exporter"
    "prometheus-exportarr-prowlarr-exporter"
    "prometheus-exportarr-bazarr-exporter"
  ];
in
{
  imports = [
    ../../nixos/optional-apps/sonarr/sonarr.nix
    ../../nixos/optional-apps/sonarr/radarr.nix
    ../../nixos/optional-apps/sonarr/bazarr.nix
    ../../nixos/optional-apps/sonarr/prowlarr.nix
    ../../nixos/optional-apps/sonarr/decluttarr.nix
    ../../nixos/optional-apps/jellyfin-rockchip.nix
    ../../nixos/optional-apps/handbrake-rockchip.nix
    ../../nixos/optional-apps/moviepilot.nix
  ];

  lantian.moviepilot.enable = true;

  systemd.tmpfiles.settings.media-apps."/nix/persistent/var/lib/media-apps"."d" = {
    mode = "0700";
    user = "root";
    group = "root";
  };

  systemd.services = lib.mkMerge [
    (lib.genAttrs gatedServices (_: {
      unitConfig.ConditionPathExists = activationMarker;
    }))
    (lib.genAttrs migratedServices (_: {
      enable = lib.mkForce false;
    }))
    {
      # Never scan an empty local directory when the NAS mount is absent.
      sonarr = {
        after = [ "mnt-storage.mount" ];
        requires = [ "mnt-storage.mount" ];
        serviceConfig.BindPaths = [
          "/mnt/storage/media-sonarr"
          "/mnt/storage/.downloads-qb-pt"
          "/mnt/storage/.downloads-qb"
        ];
      };
      radarr = {
        after = [ "mnt-storage.mount" ];
        requires = [ "mnt-storage.mount" ];
        serviceConfig.BindPaths = [
          "/mnt/storage/media-radarr"
          "/mnt/storage/.downloads-qb-pt"
          "/mnt/storage/.downloads-qb"
        ];
      };
      bazarr = {
        after = [ "mnt-storage.mount" ];
        requires = [ "mnt-storage.mount" ];
        path = [ pkgs.mediainfo ];
        serviceConfig.BindPaths = [
          "/mnt/storage/media-radarr"
          "/mnt/storage/media-sonarr"
        ];
      };
      podman-handbrake = {
        after = [ "mnt-storage.mount" ];
        requires = [ "mnt-storage.mount" ];
      };
    }
  ];
}
