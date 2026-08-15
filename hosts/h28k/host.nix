{ tags, geo, ... }:
{
  index = 125;
  system = "aarch64-linux";
  tags = with tags; [ lan-access ];
  cpuThreads = 4;
  manualDeploy = true;
  city = geo.cities."CN Ningbo";

  # SSH host keys regenerated after the board was reflashed on 2026-08-15;
  # the previous record belonged to the earlier image and no longer matches.
  ssh.ed25519 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAnVvpIL8PvnULm0/zMZv1AEU29M8AQkvkVLZXUnclK9 root@h28k";
  ssh.ed25519Fingerprints = {
    sha1 = "6b0bf7f990d510f2a7de813361e3a3ef7c93c7a7";
    sha256 = "4db3218fb849083903a633786b0a698f6c0507eff74eedbe285fbf73be4593b4";
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
