{ lib, ... }:
{
  imports = [
    ../../nixos/server.nix

    ./hardware-configuration.nix
  ];

  systemd.network.networks.eth0 = {
    matchConfig.Name = "eth0";
    networkConfig.DHCP = "ipv4";
  };

  networking.nameservers = [
    "8.8.8.8"
    "8.8.4.4"
    "1.1.1.1"
  ];

  lantian.nginxVhosts."usvm.zhyi.cc".sslCertificate = "lets-encrypt-zhyi.cc";

  # Keep enough compressed swap headroom for builds and make the
  # socket-activated Nix daemon recover after memory pressure.
  zramSwap.memoryPercent = lib.mkForce 100;
  systemd.services.nix-daemon.serviceConfig = {
    Restart = lib.mkForce "on-failure";
    RestartSec = "10s";
  };

  # cn-accel is used for the v2ray exit; skip mihomo to save memory.
  lantian.mihomo.enable = false;
}
