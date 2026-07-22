{ tags, geo, ... }:
{
  index = 112;
  tags = with tags; [ ];
  hostname = "192.168.0.1";
  cpuThreads = 2;
  manualDeploy = true;
  city = geo.cities."CN Ningbo";
  ssh.ed25519 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEPCbPTOyCxfjNZV6ATbPWTfp4Xsl2K8gasAcRRN33q+";
  interconnect = {
    name = "home-lan";
    IPv4 = "192.168.0.1";
  };
}
