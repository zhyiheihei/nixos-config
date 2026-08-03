{ tags, geo, ... }:
{
  index = 125;
  system = "aarch64-linux";
  tags = with tags; [ lan-access ];
  cpuThreads = 4;
  manualDeploy = true;
  city = geo.cities."CN Ningbo";

  ssh.ed25519 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEYeIr9Ar579oiuIYyPR7WplMRy9V5QbBufUD9PqItN7 root@h28k";
  zerotier = "d58553ad47";

  # This is a separate site LAN, not another member of home-lan.
  interconnect = {
    name = "h28k-lan";
    IPv4 = "192.168.30.1";
  };
  additionalRoutes = [ "192.168.30.0/24" ];
}
