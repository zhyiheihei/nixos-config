{
  tags,
  geo,
  constants,
  ...
}:
{
  index = 113;
  system = "aarch64-linux";

  tags = with tags; [
    server
  ];
  cpuThreads = 8;
  city = geo.cities."CN Ningbo";

  hostname = "192.168.0.68";
  ssh.ed25519 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOOcko2ZKAmqi1nKfIQCcPGY1YGM8Lzrj1/VNYWNAz41 root@venus";
  zerotier = "2991e03d81";
  interconnect = {
    name = "home-lan";
    IPv4 = "192.168.0.68";
  };
  dn42.region = constants.dn42.region.Asia-E;

  firewalled = true;
}
