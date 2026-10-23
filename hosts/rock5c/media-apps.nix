{
  lib,
  pkgs,
  ...
}:
let
  activationMarker = "/nix/persistent/var/lib/media-apps/ready";

  gatedServices = [
    "podman-handbrake"
  ];
in
{
  imports = [
    ../../nixos/optional-apps/handbrake-rockchip.nix
    ../../nixos/optional-apps/moviepilot.nix

  ];

  lantian.moviepilot.enable = true;

  virtualisation.oci-containers.containers.moviepilot.image =
    lib.mkForce "docker.io/jxxghp/moviepilot-v3:latest";

  virtualisation.oci-containers.containers.moviepilot.environment.AUTO_UPDATE_RESOURCE = "true";

  virtualisation.oci-containers.containers.moviepilot.volumes = lib.mkAfter [
    "${pkgs.writeText "dockerenv" ""}:/.dockerenv:ro"
  ];

  systemd.tmpfiles.settings.media-apps = {
    "/nix/persistent/var/lib/media-apps"."d" = {
      mode = "0700";
      user = "root";
      group = "root";
    };
  };

  systemd.services = lib.mkMerge [
    (lib.genAttrs gatedServices (_: {
      unitConfig.ConditionPathExists = activationMarker;
    }))
    {

      podman-handbrake = {
        after = [ "mnt-storage.mount" ];
        requires = [ "mnt-storage.mount" ];
      };
    }
  ];
}
