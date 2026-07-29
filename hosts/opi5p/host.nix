{ tags, geo, ... }:
{
  index = 122;
  system = "aarch64-linux";
  tags = with tags; [ ];
  # Temporary: use LAN IP until formal hostname is assigned.
  hostname = "192.168.0.62";
  cpuThreads = 8;
  manualDeploy = true;
  city = geo.cities."CN Ningbo";
  ssh.ed25519 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKlmsqnQ9i2hjfwKGeWyoSbW6279ZBFmtEDRmEbP6Xju";
  interconnect = {
    name = "home-lan";
    IPv4 = "192.168.0.62";
  };
  zerotier = "145fbb435b";
}
