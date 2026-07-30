{ tags, geo, ... }:
{
  index = 112;
  system = "aarch64-linux";
  tags = with tags; [ lan-access ];
  cpuThreads = 4;
  manualDeploy = true;
  city = geo.cities."CN Ningbo";
  ssh.ed25519 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEPCbPTOyCxfjNZV6ATbPWTfp4Xsl2K8gasAcRRN33q+";
  zerotier = "f1de7dca51";
  interconnect = {
    name = "home-lan";
    IPv4 = "192.168.0.1";
  };
}
