{
  lib,
  LT,
  ...
}:
{
  imports = [
    ../../nixos/server.nix

    ./hardware-configuration.nix

    # SFTP 备份端点（internal-sftp chroot，chroot 目录改到 1T 数据盘）。
    ../../nixos/optional-apps/sftp-server.nix
  ];

  # 本机是机群的异地备份目标，不再向外推送自身备份。
  lantian.backup.schedule = null;

  # sftp-server.nix 默认 chroot 到 /nix/persistent/sftp-server（39G 系统盘），
  # 备份机改到 1T 数据盘 /data。
  users.users.sftp.home = lib.mkForce "/data/sftp-server";

  # GreenCloud APAC 网络：DHCPv4 在该机房拿不到租约（2026-08-29 首启实测），
  # v4/v6 均为静态；网关来自救援环境实测，v6 网关是 onlink 子网路由器。
  systemd.network.networks.eth0 = {
    matchConfig.Name = "eth0";
    address = [
      "45.159.48.76/24"
      "2403:71c0:2000:1253::a/64"
    ];
    routes = [
      {
        Destination = "0.0.0.0/0";
        Gateway = "45.159.48.1";
      }
      {
        Destination = "::/0";
        Gateway = "2403:71c0:2000::1";
        GatewayOnLink = true;
      }
    ];
  };
}
