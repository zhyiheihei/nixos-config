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
    ../../nixos/optional-apps/chinesesubfinder.nix
  ];

  lantian.moviepilot.enable = true;
  lantian.chinesesubfinder.enable = true;

  # MoviePilot v3 (upgraded 2026-08-13): per the official wiki, v3 reuses the
  # v2 /config directory and SQLite DB, so volume/env mappings stay identical
  # and no data migration is needed (full backup taken before switching).
  # Overridden here at host level to keep the public optional-apps module
  # upstream-aligned.
  virtualisation.oci-containers.containers.moviepilot.image =
    lib.mkForce "docker.io/jxxghp/moviepilot-v3:latest";

  # v3's resource auto-update (curl_cffi download of user.sites.v3.bin /
  # sites.cpython-*.so) crashes the backend with SIGSEGV on this 8 GiB host
  # (2026-08-13, reproduced 3x at the same step even with memory headroom;
  # core dump then also fails to allocate). Resources are already at
  # v3.0.3/v3.0.0 on disk, so disabling updates loses nothing.
  virtualisation.oci-containers.containers.moviepilot.environment.AUTO_UPDATE_RESOURCE =
    "false";

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
