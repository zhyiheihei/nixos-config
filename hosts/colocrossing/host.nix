{ tags, geo, ... }:
{
  index = 18;
  tags = with tags; [
    lan-access
    server
  ];
  cpuThreads = 4;
  hostname = "colocrossing.zhyi.cc";
  city = geo.cities."US Bellevue";
  manualDeploy = true;

  ssh.ed25519 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFQiblSIcKmIamjtjUii7w7qKxlQCdpgNu8MzWtobXH9";

  # This VM is behind a dynamic public address. Do not publish the current
  # address as host metadata; colocrossing.zhyi.cc is maintained by DDNS.
  firewalled = true;

  # Server modules use the region when generating internal routing metadata.
  # No DN42 address is assigned until this VM actually joins DN42.
  dn42.region = 42;

  # Fill this after the regular ZeroTier service generates its node ID.
  # zerotier = "xxxxxxxxxx";
}
