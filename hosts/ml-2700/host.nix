{ tags, geo, ... }:
{
  index = 113;
  tags = with tags; [
    client
    lan-access
  ];
  city = geo.cities."CN Ningbo";
  cpuThreads = 8;
  hostname = "ml-2700.zhyi.cc";
  ssh.ed25519 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIVlH+ak3IpI3ThRUdUjo7/+n3Qr9+KRfx13yjQ8i3Ee";
  zerotier = "214f8619a9";
  interconnect = {
    name = "home-lan";
    IPv4 = "192.168.2.53";
  };
}
