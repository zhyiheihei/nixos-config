{
  lib,
  config,
  LT,
  ...
}:
{
  imports = [
    ../../nixos/server.nix

    ./hardware-configuration.nix
  ];

  # x86_64 UEFI 物理机，GRUB EFI（同 google）。
  boot.loader.grub = {
    efiSupport = true;
    device = "nodev";
  };

  # 有线口 eno0 静态接入家庭 LAN（基础设施静态地址，DHCP 池外）。
  systemd.network.networks."10-chromebox-lan" = {
    matchConfig.Name = "eno0";
    address = [ "${LT.this.interconnect.IPv4}/24" ];
    networkConfig.IPv6AcceptRA = "yes";
    routes = [
      {
        Destination = "0.0.0.0/0";
        Gateway = "192.168.0.1";
      }
    ];
  };
  networking.networkmanager.enable = lib.mkForce false;

  # NFS 挂载需要等物理网络就绪。通用策略禁用了全局 wait-online，
  # 这里启用按接口的实例。
  systemd.targets.network-online.wants = [ "systemd-networkd-wait-online@eno0.service" ];

  networking.hosts = {
    "${LT.this.interconnect.IPv4}" = [ config.networking.hostName ];
  };
}
