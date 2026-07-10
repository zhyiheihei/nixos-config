{ tags, geo, ... }:
{
  index = 116;
  tags = with tags; [ ];
  city = geo.cities."US Bellevue";
  cpuThreads = 8;
  hostname = "192.168.2.237";
  manualDeploy = true;
  ssh.ed25519 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIVlH+ak3IpI3ThRUdUjo7/+n3Qr9+KRfx13yjQ8i3Ee";
}
