{ LT, ... }:
{
  imports = [ ../../nixos/optional-apps/syncthing ];

  # Keep the private Notes on the Syncthing-backed persistent media tree, then
  # expose it at the normal Documents path through bindfs, mirroring the
  # author's client setup.
  lantian.syncthing.storage = "/nix/persistent/media";

  fileSystems."/home/zhyi/Documents/Notes" = {
    device = "/nix/persistent/media/Notes";
    fsType = "fuse.bindfs";
    options = LT.constants.bindfsMountOptions' [
      "force-user=zhyi"
      "force-group=zhyi"
      "perms=700"
      "create-for-user=zhyi"
      "create-for-group=users"
      "create-with-perms=755"
      "chmod-ignore"
    ];
  };

  systemd.tmpfiles.settings.knowledge-chain-notes."/nix/persistent/media/Notes"."d" = {
    mode = "0755";
    user = "syncthing";
    group = "syncthing";
  };

  home-manager.users.zhyi.imports = [ ./knowledge-chain-home.nix ];
}
