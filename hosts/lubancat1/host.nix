{ tags, geo, ... }:
{
  index = 124;
  system = "aarch64-linux";
  tags = with tags; [
    lan-access
    low-ram
  ];
  cpuThreads = 4;
  city = geo.cities."CN Ningbo";
  ssh.ed25519 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOhJN9lnKi13oHi9Gdk9KkBiOg9p8qcp29Bm2+Jj2e5j root@lubancat1";
  zerotier = "fde3beab16";
  interconnect = {
    name = "home-lan";
    IPv4 = "192.168.0.65";
  };
}
