{ geo, constants, ... }:
{
  index = 240;
  tags = [ ];
  cpuThreads = 2;
  city = geo.cities."CN Ningbo";
  ssh.ed25519 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEL+VnRYwULTdXkJtOCqoKY4COzWxHNz9glsndnSbZxl";
  manualDeploy = true;
  dn42.region = constants.dn42.region.Asia-E;
}
