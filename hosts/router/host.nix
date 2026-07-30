{ tags, geo, ... }:
{
  index = 112;
  system = "aarch64-linux";
  # Included in `make all`, but kept out of automatic reboot groups.
  tags = with tags; [ "default" ];
  hostname = "192.168.0.1";
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
