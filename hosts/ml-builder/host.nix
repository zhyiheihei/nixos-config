{
  tags,
  geo,
  constants,
  ...
}:
{
  index = 114;
  tags = with tags; [
    lan-access
    nix-builder
  ];

  cpuThreads = 28;

  hostname = "ml-builder.zhyi.xin";

  city = geo.cities."CN Ningbo";

  ssh.ed25519 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEL+VnRYwULTdXkJtOCqoKY4COzWxHNz9glsndnSbZxl";

  zerotier = "2c86750714";
  manualDeploy = true;
  interconnect = {
    name = "home-lan";
    IPv4 = "192.168.0.50";
  };

  dn42.region = constants.dn42.region.Asia-E;

}
