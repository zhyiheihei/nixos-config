{
  LT,
  ...
}:
{
  imports = [
    ../../nixos/server.nix

    ./hardware-configuration.nix

    ../../nixos/optional-apps/elasticsearch.nix
    ../../nixos/optional-apps/grafana.nix
    ../../nixos/optional-apps/prometheus
  ];

  systemd.network.networks.ens18 = {
    address = [ "${LT.this.interconnect.IPv4}/24" ];
    gateway = [ "192.168.2.2" ];
    matchConfig.Name = "ens18";
    networkConfig.IPv6AcceptRA = "yes";
    ipv6AcceptRAConfig.DHCPv6Client = "no";
  };
}
