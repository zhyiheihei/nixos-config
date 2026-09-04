{
  LT,
  lib,
  pkgs,
  config,
  ...
}:
{
  boot.extraModprobeConfig = ''
    options nfs nfs4_disable_idmapping=1
    options nfsd nfs4_disable_idmapping=1
  '';

  # nixpkgs 26.11pre nfsd 模块回归的规避（supportedFilesystems 被整值定义
  # 冲掉、nfs-server unit 缺 ExecStart），nixpkgs 修复后可整体移除。
  boot.supportedFilesystems = lib.mkForce (
    map (fs: fs.fsType) (lib.attrValues config.fileSystems) ++ [ "nfs" ]
  );
  boot.kernelModules = [ "nfsd" ];

  services.nfs.server = {
    enable = true;
    nproc = 64;
    hostName = LT.this.ltnet.IPv4;
    lockdPort = LT.port.NFS.LockD;
    mountdPort = LT.port.NFS.MountD;
    statdPort = LT.port.NFS.StatD;

    exports = ''
      /run/nfs 198.18.0.0/24(ro,fsid=0,no_subtree_check)
    '';
  };

  # 按 nfs-utils 2.9.x vendor unit 补齐 exec 行（nfsdctl autostart，
  # rpc.nfsd 兜底）；oneshot 不设 Restart（策略断言对 oneshot 豁免）。
  systemd.services.nfs-server = {
    after = [
      "network-online.target"
      "proc-fs-nfsd.mount"
    ];
    requires = [ "proc-fs-nfsd.mount" ];
    wants = [ "network-online.target" ];
    path = [ pkgs.kmod ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStartPre = "-${pkgs.nfs-utils}/bin/exportfs -r";
      ExecStart = "${pkgs.runtimeShell} -c '${pkgs.nfs-utils}/bin/nfsdctl autostart || ${pkgs.nfs-utils}/bin/rpc.nfsd'";
      ExecStop = "${pkgs.runtimeShell} -c '${pkgs.nfs-utils}/bin/nfsdctl threads 0 || ${pkgs.nfs-utils}/bin/rpc.nfsd 0'";
      ExecStopPost = [
        "${pkgs.nfs-utils}/bin/exportfs -au"
        "${pkgs.nfs-utils}/bin/exportfs -f"
      ];
    };
  };

  systemd.tmpfiles.settings = lib.mkIf (lib.hasInfix "/run/nfs" config.services.nfs.server.exports) {
    nfs = {
      "/run/nfs"."d" = {
        mode = "755";
        user = "root";
        group = "root";
      };
    };
  };
}
