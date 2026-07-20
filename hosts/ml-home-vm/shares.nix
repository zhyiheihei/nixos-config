{
  lib,
  LT,
  config,
  ...
}:
{
  imports = [
    ../../nixos/optional-apps/nfs.nix
    ../../nixos/optional-apps/samba.nix
  ];

  services.nfs.server.exports =
    let
      opts = "rw,insecure,no_subtree_check,mountpoint,all_squash,fsid=1,anonuid=${builtins.toString config.users.users.zhyi.uid},anongid=${builtins.toString config.users.groups.zhyi.gid}";
      hostOpts = lib.concatMapStringsSep " " (ip: "${ip}(${opts})") (
        lib.mapAttrsToList (_: host: host.ltnet.IPv4) (LT.hostsWithTag LT.tags."lan-access")
      );
    in
    ''
      /run/nfs/storage ${hostOpts}
    '';

  services.samba.settings.storage = {
    path = "/mnt/storage";
    browseable = "yes";
    "read only" = "no";
    "guest ok" = "no";
    "create mask" = "0644";
    "directory mask" = "0755";
    "force user" = "root";
    "force group" = "users";
    "valid users" = "zhyi";
    "veto files" = "/._*/.DS_Store/Thumbs.db/";
    "delete veto files" = "yes";
  };

  lantian.syncthing.storage = "/mnt/storage/media";

  fileSystems = {
    "/run/sftp" = lib.mkForce {
      device = "/mnt/storage";
      fsType = "fuse.bindfs";
      depends = [ "/mnt/storage" ];
      options = LT.constants.bindfsMountOptions' [
        "_netdev"
        "force-user=sftp"
        "force-group=sftp"
        "perms=700"
        "create-for-user=zhyi"
        "create-for-group=users"
        "create-with-perms=755"
        "chmod-ignore"
      ];
    };
    "/run/nfs/storage" = {
      device = "/mnt/storage";
      fsType = "fuse.bindfs";
      depends = [ "/mnt/storage" ];
      options = LT.constants.bindfsMountOptions' [
        "_netdev"
        "force-user=zhyi"
        "force-group=zhyi"
        "perms=700"
        "create-for-user=zhyi"
        "create-for-group=users"
        "create-with-perms=755"
        "chmod-ignore"
      ];
    };
  };

  users.users.sftp.home = lib.mkForce "/run/sftp";
}
