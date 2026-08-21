{
  tags,
  geo,
  constants,
  ...
}:
{
  index = 122;
  system = "aarch64-linux";
  # Native ARM fallback builder: this RK3588 handles aarch64 derivations
  # whose build scripts must execute target code; the dedicated build path
  # remains ml-builder (see docs/agent/hosts-overview.md).
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
  # Server-role BIRD configuration consumes the region even without dn42.
  dn42.region = constants.dn42.region.Asia-E;
  zerotier = "7e7ce20750";
}
