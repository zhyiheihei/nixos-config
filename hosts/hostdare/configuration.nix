{
  inputs,
  LT,
  ...
}:
{
  imports = [
    ../../nixos/server.nix

    ./hardware-configuration.nix

    "${inputs.secrets}/nixos-hidden-module/aacd9f37de95f98d"
  ];

  systemd.network.networks.eth0 = {
    matchConfig.Name = "eth0";
    networkConfig.DHCP = "ipv4";
  };

  lantian.nginxVhosts."hostdare.zhyi.xin".sslCertificate = "lets-encrypt-zhyi.xin";

  # hostdare 流量限额小，关闭每日自动备份；需要时手动触发：
  #   systemctl start backup-nix-persistent.service
  lantian.backup.schedule = null;
}
