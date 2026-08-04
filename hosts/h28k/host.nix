{ tags, geo, ... }:
{
  index = 125;
  system = "aarch64-linux";
  tags = with tags; [ lan-access ];
  cpuThreads = 4;
  manualDeploy = true;
  city = geo.cities."CN Ningbo";

  ssh.ed25519 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEYeIr9Ar579oiuIYyPR7WplMRy9V5QbBufUD9PqItN7 root@h28k";
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
