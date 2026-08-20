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
  # launchd daemon 以 root 运行挂载脚本：先建挂载点目录再 mount_nfs。
  # 用 RunAtLoad 而非 KeepAlive：mount 成功即退出，无需常驻。
  # 挂载脚本必须自带 mkdir -p /Volumes/nixos——nix-darwin 的 activation
  # 阶段顺序在 launchd 加载之后，依赖 activation 建目录会导致 mount_nfs
  # 因挂载点不存在而 exit=2（实测 realpath /Volumes/nixos 失败）。
  launchd.daemons.mount-qnap-nixos = {
    script = ''
      mkdir -p /Volumes/nixos
      /sbin/mount_nfs -o vers=3,hard,resvport 192.168.0.40:/nixos /Volumes/nixos
    '';
    serviceConfig = {
      RunAtLoad = true;
      # QNAP NFS 要求保留端口，mount_nfs 必须带 resvport，否则报
      # err=10020（nfs client/server protocol prob）。
      # 挂载源与 opi5p/rock5c 一致（同一份 QNAP /nixos），macOS 用
      # /Volumes/nixos（根分区只读，无法用 Linux 的 /mnt/storage）。
      ProcessType = "Background";
    };
  };
}
