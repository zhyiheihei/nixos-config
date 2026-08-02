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
  manualDeploy = true;
  ssh.ed25519 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIVlH+ak3IpI3ThRUdUjo7/+n3Qr9+KRfx13yjQ8i3Ee";
  ssh.ed25519Fingerprints = {
    sha1 = "ba391cef1ead61aeb83c7e336e5f4f7f50dee557";
    sha256 = "71edf2507ac21e617da7a2032a47a3f697b57d8b1942c7183571813578a9b3be";
  };
  zerotier = "214f8619a9";
  interconnect = {
    name = "home-lan";
    IPv4 = "192.168.0.53";
  };
}
