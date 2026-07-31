{ tags, geo, ... }:
{
  index = 123;
  system = "aarch64-linux";
  tags = with tags; [ lan-access ];
  cpuThreads = 8;
  city = geo.cities."CN Ningbo";
  ssh.ed25519 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOVPKMHQqr+gzsju2KvpM4GcO2G08O9AXFOxZ4UGJMJ9 root@rock5c";
  interconnect = {
    name = "home-lan";
    IPv4 = "192.168.0.64";
  };
  zerotier = "8a55fde716";
}
