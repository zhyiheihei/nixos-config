# nixpkgs 26.11pre nfsd 模块回归的规避（supportedFilesystems 被整值定义冲掉、
# nfs-server unit 缺 ExecStart）。上游修复落地后本模块可整体删除。
{
  lib,
  pkgs,
  config,
  ...
}:
{
  boot.supportedFilesystems = lib.mkForce (
    map (fs: fs.fsType) (lib.attrValues config.fileSystems) ++ [ "nfs" ]
  );
  boot.kernelModules = [ "nfsd" ];

  # 按 nfs-utils 2.9.x vendor unit 补齐 exec 行（nfsdctl autostart，
  # rpc.nfsd 兜底）；oneshot 不设 Restart（systemd 禁止 oneshot 配 Restart，
  # mkForce 整体替换上游 nfs-server.serviceConfig，避免混入 Restart=on-failure）。
  systemd.services.nfs-server = {
    after = [
      "network-online.target"
      "proc-fs-nfsd.mount"
    ];
    requires = [ "proc-fs-nfsd.mount" ];
    wants = [ "network-online.target" ];
    path = [ pkgs.kmod ];
    serviceConfig = lib.mkForce {
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
}
