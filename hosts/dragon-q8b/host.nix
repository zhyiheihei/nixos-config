{
  tags,
  geo,
  constants,
  ...
}:
{
  index = 129;
  system = "aarch64-linux";
  tags = with tags; [
    lan-access
    server
  ];
  manualDeploy = true;
  cpuThreads = 8;
  city = geo.cities."CN Ningbo";
  ssh.ed25519 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFHX4OQA+OsOx2jxm8sqFI6a08kbC8duwP5ymzPykN5Z root@dragon-q8b";
  interconnect = {
    name = "home-lan";
    IPv4 = "192.168.0.66";
  };
  # Server-role BIRD configuration consumes the region even without dn42.
  dn42.region = constants.dn42.region.Asia-E;
}
