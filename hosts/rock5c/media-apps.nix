{
  lib,
  pkgs,
  ...
}:
let
  activationMarker = "/nix/persistent/var/lib/media-apps/ready";
  # The sonarr/radarr/bazarr/prowlarr chain was replaced by MoviePilot
  # (2026-08-14) and is no longer mounted here; the modules remain available
  # for opi5p and can be re-imported for a rollback if ever needed.
  gatedServices = [
    "jellyfin"
    "handbrake"
    "podman-handbrake"
  ];
in
{
  imports = [
    ../../nixos/optional-apps/jellyfin-rockchip.nix
    ../../nixos/optional-apps/handbrake-rockchip.nix
    ../../nixos/optional-apps/moviepilot.nix
  ];

  # MoviePilot migrated to lubancat1 as the nix package (2026-08-14);
  # the docker container stays disabled here for rollback.  Data lives at
  # /nix/persistent/var/lib/moviepilot and was rsynced to lubancat1.
  lantian.moviepilot.enable = lib.mkForce false;

  systemd.tmpfiles.settings.media-apps."/nix/persistent/var/lib/media-apps"."d" = {
    mode = "0700";
    user = "root";
    group = "root";
  };

  systemd.services = lib.mkMerge [
    (lib.genAttrs gatedServices (_: {
      unitConfig.ConditionPathExists = activationMarker;
    }))
    {
      # Never scan an empty local directory when the NAS mount is absent.
      podman-handbrake = {
        after = [ "mnt-storage.mount" ];
        requires = [ "mnt-storage.mount" ];
      };
    }
  ];
}
