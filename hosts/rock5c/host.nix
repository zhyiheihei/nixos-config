{ tags, geo, ... }:
{
  index = 123;
  system = "aarch64-linux";
  tags = with tags; [ lan-access ];
  cpuThreads = 8;
  city = geo.cities."CN Ningbo";

  # Keep the unfinished board outside make all until its persistent SSH host
  # key, permanent MAC address and ZeroTier identity have been collected.
  manualDeploy = true;
  ssh.ed25519 = null;
  interconnect = {
    name = "home-lan";
    IPv4 = "192.168.0.64";
  };
  zerotier = null;
}
