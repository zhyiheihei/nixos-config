{ tags, geo, ... }:
{
  index = 112;
  system = "aarch64-linux";
  hostname = "192.168.0.1";
  tags = with tags; [ lan-access ];
  cpuThreads = 4;
  manualDeploy = true;
  city = geo.cities."CN Ningbo";
  ssh.ed25519 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEPCbPTOyCxfjNZV6ATbPWTfp4Xsl2K8gasAcRRN33q+";
  ssh.ed25519Fingerprints = {
    sha1 = "ed6428b549f55483dd98dabff71fa879d8a49fee";
    sha256 = "94e968ad9dc3fedbb317ba68a1be9f27d576c45f037cfebf748fe0306731897a";
  };
  zerotier = "f1de7dca51";
  interconnect = {
    name = "home-lan";
    IPv4 = "192.168.0.1";
  };
}
