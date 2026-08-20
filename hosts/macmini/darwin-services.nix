# macmini 服务端地基：声明式挂载 QNAP 媒体源。
#
# macOS 根分区只读，无法像 Linux 主机一样用 /mnt/storage（实测 /mnt 只读）。
# 这里用 macOS 通用挂载点 /Volumes/nixos，挂载源与 opi5p/rock5c 完全一致
# （同一份 QNAP 192.168.0.40:/nixos），保证媒体数据跨主机同源、不重复存储。
#
# QNAP NFS 要求客户端用保留端口（<1024），macOS 上必须加 resvport 选项，
# 否则挂载报 err=10020（nfs client/server protocol prob）。这是 macOS 挂
# QNAP 与 Linux 主机（内核 nfs + nconnect）不同的地方。
#
# 只改 macmini 主机级，不碰公共模块、不碰 opi5p/rock5c。
{ lib, pkgs, ... }:

{
  # 挂载点目录由 activation 创建（/Volumes 位于可写数据卷）。
  system.activationScripts.mount-qnap.text = ''
    mkdir -p /Volumes/nixos
  '';

  # launchd daemon 以 root 运行 mount_nfs，开机自动挂载 QNAP /nixos。
  # 用 RunAtLoad 而非 KeepAlive：mount 命令成功即退出，无需常驻；
  # QNAP 暂不可达时由 activation 阶段兜底，或手动重挂。
  launchd.daemons.mount-qnap-nixos = {
    serviceConfig = {
      RunAtLoad = true;
      ProgramArguments = [
        "/sbin/mount_nfs"
        "-o"
        "vers=3,hard,resvport"
        "192.168.0.40:/nixos"
        "/Volumes/nixos"
      ];
    };
  };
}
