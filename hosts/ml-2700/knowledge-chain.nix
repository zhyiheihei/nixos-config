{ lib, ... }:
{
  imports = [ ../../nixos/optional-apps/syncthing ];

  lantian.syncthing.storage = "/nix/persistent/media";

  # Notes stays a plain directory; give the syncthing service write access
  # through the zhyi group instead of adding custom bind mounts.
  users.groups.zhyi.members = [ "syncthing" ];

  systemd.services.syncthing.serviceConfig.ReadWritePaths = lib.mkForce [
    "/run/syncthing-files"
    "/home/zhyi/Documents/Notes"
  ];

  home-manager.users.zhyi.imports = [ ./knowledge-chain-home.nix ];
}
