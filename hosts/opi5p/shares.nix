{
  config,
  lib,
  LT,
  ...
}:
{
  imports = [
    ../../nixos/optional-apps/nfs.nix
    ../../nixos/optional-apps/nfs-server-regression-fix.nix
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
      # _netdev：底层是 NFS remote 挂载，本挂载必须归 remote-fs 链，
      # 否则 local-fs 成员依赖 remote 挂载必然成 ordering cycle。
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
      # _netdev：同 /run/sftp，底层 NFS 之上的 bindfs 归 remote-fs 断环。
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
