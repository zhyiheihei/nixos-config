{ LT, ... }:
{
  imports = [
    ../../nixos/minimal.nix
    ../../nixos/optional-apps/attic-watch-store.nix

    ./hardware-configuration.nix
  ];

  systemd.network.networks.eth0 = {
    address = [ "${LT.this.interconnect.IPv4}/24" ];
    gateway = [ "192.168.3.1" ];
    matchConfig.Name = "eth0";
    networkConfig.IPv6AcceptRA = "yes";
    ipv6AcceptRAConfig.DHCPv6Client = "no";
  };
}
