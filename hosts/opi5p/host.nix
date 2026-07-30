{ tags, geo, ... }:
{
  index = 122;
  system = "aarch64-linux";
  # Included in `make all`, but kept out of automatic reboot groups.
  tags = with tags; [ "default" ];
  # Temporary: use LAN IP until formal hostname is assigned.
  hostname = "192.168.0.62";
  cpuThreads = 8;
  manualDeploy = true;
  city = geo.cities."CN Ningbo";
  ssh.ed25519 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIITTMAnkcLtBaK31sz6e7aGEvSkqKZuEeeJETBmK33Ef root@opi5p";
  interconnect = {
    name = "home-lan";
    IPv4 = "192.168.0.62";
  };
  # Reinstalled on 2026-07-30; this is the persistent ZeroTier identity
  # generated on the new NixOS installation, not the retired Armbian one.
  zerotier = "7e7ce20750";
}
