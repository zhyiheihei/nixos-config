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
  hostname = "36.50.85.113";
  city = geo.cities."CN Hong Kong";
  ssh.ed25519 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEBFLiDovNcpzs3OhpkCoc/ByL6DoTdz1H8LlZojX1Pn";
  zerotier = "94602ea0ad";
  public = {
    IPv4 = "36.50.85.113";
  };
  dn42 = {
    IPv4 = "172.20.46.226";
    region = 52;
  };
}
