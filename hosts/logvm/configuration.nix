{
  LT,
  ...
}:
{
  imports = [
    ../../nixos/server.nix

    ./hardware-configuration.nix

    ../../nixos/optional-apps/elasticsearch.nix
  ];

  systemd.network.networks.ens18 = {
    address = [ "${LT.this.interconnect.IPv4}/24" ];
    gateway = [ "192.168.2.2" ];
    matchConfig.Name = "ens18";
    networkConfig.IPv6AcceptRA = "yes";
    ipv6AcceptRAConfig.DHCPv6Client = "no";
  };

  networking.hosts = {
    # LAN 直连 colocrossing，绕过 hairpin NAT 访问 attic
    "${LT.hosts.colocrossing.interconnect.IPv4}" = [ "attic.zhyi.xin" ];
  };
}
