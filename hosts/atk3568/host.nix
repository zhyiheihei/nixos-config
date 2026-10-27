{
  tags,
  geo,
  constants,
  ...
}:
{
  index = 133;
  system = "aarch64-linux";
  tags = with tags; [
    lan-access
    server
  ];
  cpuThreads = 4;
  city = geo.cities."CN Ningbo";
  ssh.ed25519 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBvIfnO4K3mHsKCRKYT794hssE+tVuSfF7QpcpgwAUI/";
  interconnect = {
    name = "home-lan";
    IPv4 = "192.168.0.63";
  };

  dn42.region = constants.dn42.region.Asia-E;
}
