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
  # TODO: generate and fill in after first boot or key generation.
  ssh.ed25519 = null;
  interconnect = {
    name = "home-lan";
    IPv4 = "192.168.0.62";
  };
}
