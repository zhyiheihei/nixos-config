{ tags, geo, ... }:
{
  index = 118;
  tags = with tags; [
    client
    lan-access

  ];
  city = geo.cities."CN Ningbo";
  cpuThreads = 18;

  vramGB = 22;
  hostname = "ml-laptop.zhyi.xin";
  manualDeploy = true;

  ssh.ed25519 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICERfSdIV4jVRBkEfTOmdNcnzomd3g5e4s8zpqpsbevi";

  zerotier = "08d6522fba";
  interconnect = {
    name = "home-lan";
    IPv4 = "192.168.0.55";
  };
}
