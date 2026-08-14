{ tags, geo, ... }:
{
  index = 125;
  system = "aarch64-linux";
  tags = with tags; [ lan-access ];
  cpuThreads = 4;
  manualDeploy = true;
  city = geo.cities."CN Ningbo";

  ssh.ed25519 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEYeIr9Ar579oiuIYyPR7WplMRy9V5QbBufUD9PqItN7 root@h28k";
  ssh.ed25519Fingerprints = {
    sha1 = "f0e522d6e93f11c6c9ec831c6d514f3a24defe36";
    sha256 = "8ebc2ac67fa95ac4f405a524c35e61206cd8c5a3c8f1d9e2cdcad388ae907d1d";
  };
  # Must match the node's live identity; the previous value (d58553ad47)
  # was a different node, so the controller denied it (ACCESS_DENIED).
  zerotier = "368d3cf42b";

  # This is a separate site LAN, not another member of home-lan.
  interconnect = {
    name = "h28k-lan";
    IPv4 = "192.168.30.1";
  };
  additionalRoutes = [ "192.168.30.0/24" ];
}
