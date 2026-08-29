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

  lantian.nginxVhosts."google.zhyi.xin".sslCertificate = "lets-encrypt-zhyi.xin";

  # Keep enough compressed swap headroom for builds and make the
  # socket-activated Nix daemon recover after memory pressure.
  zramSwap.memoryPercent = lib.mkForce 100;
  systemd.services.nix-daemon.serviceConfig = {
    Restart = lib.mkForce "on-failure";
    RestartSec = "10s";
  };

}
