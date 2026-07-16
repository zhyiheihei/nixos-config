{ tags, geo, ... }:
{
  index = 116;
  tags = with tags; [
    lan-access
    nix-builder
  ];
  city = geo.cities."CN Ningbo";
  cpuThreads = 16;
  hostname = "pve-5700u.zhyi.cc";
  ssh.ed25519 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICo2gngU3agJnmKjwtp6qLF5YZH1EhmON8tKmdDyOGBd";
  manualDeploy = true;
  interconnect = {
    name = "home-lan";
    IPv4 = "192.168.2.54";
  };
}
