{ tags, geo, ... }:
{
  index = 125;
  system = "aarch64-linux";
  tags = with tags; [ lan-access ];
  cpuThreads = 4;
  manualDeploy = true;
  city = geo.cities."CN Ningbo";

  ssh.ed25519 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAnVvpIL8PvnULm0/zMZv1AEU29M8AQkvkVLZXUnclK9 root@h28k";

  zerotier = "368d3cf42b";

  interconnect = {
    name = "h28k-lan";
    IPv4 = "192.168.30.1";
  };
  additionalRoutes = [ "192.168.30.0/24" ];
}
