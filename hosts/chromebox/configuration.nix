{
  lib,
  config,
  LT,
  ...
}:
{
  imports = [
    ../../nixos/server.nix

    ../../nixos/optional-apps/ncps-client.nix

    ./hardware-configuration.nix
    ./media-automation.nix
  ];

  # 摘除 server 标签后 backup 默认关闭，显式启用（同 ml-laptop 惯例）。
  lantian.backup.enable = true;

  boot.loader.grub = {
    efiSupport = true;
    device = "nodev";
  };

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

  # 通用策略禁用全局 wait-online，NFS 挂载依赖按接口实例。
  systemd.targets.network-online.wants = [ "systemd-networkd-wait-online@eno0.service" ];

  networking.hosts = {
    "${LT.this.interconnect.IPv4}" = [ config.networking.hostName ];
  };
}
