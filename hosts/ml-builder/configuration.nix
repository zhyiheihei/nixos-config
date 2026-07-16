{ pkgs, LT, ... }:
{
  imports = [
    ../../nixos/minimal.nix
    # ../../nixos/optional-apps/attic-watch-store.nix
    ../../nixos/client-apps/vscode-remote-env.nix
    ./hardware-configuration.nix
  ];

  systemd.network.networks.eth0 = {
    address = [ "${LT.this.interconnect.IPv4}/24" ];
    gateway = [ "192.168.2.2" ];
    matchConfig.Name = "eth0";
    networkConfig.IPv6AcceptRA = "yes";
    ipv6AcceptRAConfig.DHCPv6Client = "no";
  };

  networking.hosts = {
    "192.168.2.116" = [ "openclash.zhyi.cc" ];
    "${LT.hosts.ml-home-vm.interconnect.IPv4}" = [ "ml-home-vm.zhyi.cc" ];
    "${LT.hosts."pve-5700u".interconnect.IPv4}" = [ "pve-5700u.zhyi.cc" ];
    "${LT.hosts.colocrossing.interconnect.IPv4}" = [ "attic.zhyi.xin" ];
  };

  services.openssh.settings.MaxStartups = "64:30:128";

  environment.systemPackages = with pkgs; [
    age
    gnumake
    sops
    ssh-to-age
  ];
}
