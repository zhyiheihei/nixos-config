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

  # GreenCloud APAC 网络：v4 DHCP；v6 为静态 /64（路由子网，网关 onlink）。
  systemd.network.networks.eth0 = {
    matchConfig.Name = "eth0";
    address = [ "2403:71c0:2000:1253::a/64" ];
    routes = [
      {
        Destination = "::/0";
        Gateway = "2403:71c0:2000::1";
        GatewayOnLink = true;
      }
    ];
    networkConfig.DHCP = "ipv4";
  };
}
