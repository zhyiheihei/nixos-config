{
  tags,
  geo,
  constants,
  ...
}:
{
  index = 122;
  system = "aarch64-linux";

  tags = with tags; [
    lan-access
    nix-builder
    server
  ];
  cpuThreads = 8;
  city = geo.cities."CN Ningbo";

  ssh.ed25519 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIITTMAnkcLtBaK31sz6e7aGEvSkqKZuEeeJETBmK33Ef root@opi5p";
  interconnect = {
    name = "home-lan";
    IPv4 = "192.168.0.62";
  };

  dn42.region = constants.dn42.region.Asia-E;
  zerotier = "7e7ce20750";
}
