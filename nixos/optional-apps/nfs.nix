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

  # nfsd.nix 虽设 boot.supportedFilesystems = [ "nfs" ]，但该版本会被
  # tasks/filesystems.nix 按 fileSystems 推导的整值定义覆盖（合并不生效，
  # 纯服务端没有 NFS 挂载点，nfs 被冲掉），导致 systemd.packages 不引入
  # nfs-utils：vendor 的 proc-fs-nfsd.mount 缺失、/etc/nfs.conf（threads=64
  # 等的载体）不生成。这里以更高优先级复刻同样的推导并强制加上 nfs。
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

  # nixos-unstable（26.11pre）重写 nfsd.nix 后不再为 nfs-server.service 生成
  # ExecStart/ExecStop（命令挪进了 nfs-utils 自带的 vendor unit），但 NixOS
  # 生成的 unit 会整体覆盖 vendor unit，结果加载报 bad-setting、nfsd 起不来
  # （上游 nixos-config-exam 同样受影响）。这里按 nfs-utils 2.9.x vendor unit
  # 原样补齐 exec 行；nproc 等选项已由 tasks/filesystems/nfs.nix 翻译进
  # /etc/nfs.conf，nfsdctl autostart 会读取。oneshot + RemainAfterExit 与
  # Restart= 互斥，故不设 Restart（Restart 策略断言对 oneshot 服务豁免）。
  # nixpkgs 修复后可整体移除。
  systemd.services.nfs-server = {
    after = [
      "network-online.target"
      "proc-fs-nfsd.mount"
    ];
    requires = [ "proc-fs-nfsd.mount" ];
    wants = [ "network-online.target" ];
    # nfsdctl 依赖内核 nfsd generic netlink（部分内核/时序下解析失败），
    # 保留 vendor unit 的 rpc.nfsd 兜底；path 提供 modprobe 供 nfsdctl 内部
    # 加载模块用。
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
