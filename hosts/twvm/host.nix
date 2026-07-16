{ tags, geo, ... }:
{
  index = 2;
  tags = with tags; [
    low-disk
    low-ram
    public-facing
    server
  ];
  cpuThreads = 1;
  hostname = "140.235.38.39";
  city = geo.cities."CN Taipei";
  ssh.ed25519 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEZ4PresW6G2jVfJWVfjajdo4ersMRfkl97nKveYoVjC";
  zerotier = "94602ea0ad";
  public = {
    IPv4 = "140.235.38.39";
    IPv6 = "2407:cdc0:f008:12a::";
  };
  ltnet.peers = [ "jpvm" ];
  dn42 = {
    IPv4 = "172.20.46.226";
    region = 52;
  };
}
