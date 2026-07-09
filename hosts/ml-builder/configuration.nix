{ ... }:
{
  imports = [
    ../../nixos/minimal.nix
    ../../nixos/optional-apps/attic-watch-store.nix

    ./hardware-configuration.nix
  ];

  systemd.network.networks.eth0 = {
    matchConfig.Name = "eth0";
    networkConfig = {
      DHCP = "yes";
      IPv6AcceptRA = "yes";
    };
    ipv6AcceptRAConfig.DHCPv6Client = "no";
  };
}
