{
  tags,
  geo,
  constants,
  ...
}:
{
  index = 131;
  system = "x86_64-linux";
  tags = with tags; [
    lan-access
    server
  ];
  cpuThreads = 8;
  city = geo.cities."CN Ningbo";
  ssh.ed25519 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOWizfDOy55dZqrVSLJ9b0loTER6/TxV3B55kN6BPdW5 root@nixos";
  interconnect = {
    name = "home-lan";
    IPv4 = "192.168.0.56";
  };
  # Server-role BIRD configuration consumes the region even without dn42.
  dn42.region = constants.dn42.region.Asia-E;
}
