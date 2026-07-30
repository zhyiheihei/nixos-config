{ tags, geo, ... }:
{
  index = 122;
  system = "aarch64-linux";
  # Follow the author's native-architecture builder topology: this RK3588
  # handles aarch64 derivations whose build scripts must execute target code.
  tags = with tags; [
    lan-access
    nix-builder
  ];
  cpuThreads = 8;
  city = geo.cities."CN Ningbo";
  ssh.ed25519 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIITTMAnkcLtBaK31sz6e7aGEvSkqKZuEeeJETBmK33Ef root@opi5p";
  interconnect = {
    name = "home-lan";
    IPv4 = "192.168.0.62";
  };
  zerotier = "7e7ce20750";
}
