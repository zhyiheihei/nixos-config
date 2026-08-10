{ lib, ... }:
{
  imports = [ ../../nixos/optional-apps/syncthing ];

  lantian.syncthing.storage = "/nix/persistent/media";

  # Notes stays a plain directory; give the syncthing service write access
  # through the zhyi group instead of adding custom bind mounts.
  users.groups.zhyi.members = [ "syncthing" ];

  systemd.services.syncthing.serviceConfig = {
    ReadWritePaths = lib.mkForce [
      "/run/syncthing-files"
      "/home/zhyi/Documents/Notes"
    ];
    # PrivateUsers remaps uid/gid and breaks file/ACL access to /home.
    PrivateUsers = lib.mkForce false;
  };

  home-manager.users.zhyi.imports = [ ./knowledge-chain-home.nix ];
}
