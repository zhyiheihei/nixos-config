{
  inputs,
  lib,
  pkgs,
  LT,
  ...
}:
let
  adminSSHKeys = import (inputs.secrets + "/ssh/lantian.nix");
  deploySSHKey = lib.findFirst
    (key: lib.hasSuffix " github-bot" key)
    (throw "github-bot SSH public key not found")
    adminSSHKeys;
  deploySSHKeyFile = pkgs.writeText "github-bot.pub" "${deploySSHKey}\n";
in
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
    "${LT.hosts.ml-home-vm.interconnect.IPv4}" = [
      "ml-home-vm.zhyi.cc"
      "openclash.zhyi.cc"
    ];
    "${LT.hosts."pve-5700u".interconnect.IPv4}" = [ "pve-5700u.zhyi.cc" ];
    "${LT.hosts.logvm.interconnect.IPv4}" = [ "logvm.zhyi.cc" ];
    "${LT.hosts.colocrossing.interconnect.IPv4}" = [
      "attic.zhyi.xin"
      "vaults3.zhyi.cc"
    ];
  };

  services.openssh.settings.MaxStartups = "64:30:128";

  programs.ssh.extraConfig = lib.mkBefore ''
    Host *.zhyi.cc 36.50.85.113
      IdentityFile ${deploySSHKeyFile}
      IdentitiesOnly yes
  '';

  environment.systemPackages = with pkgs; [
    age
    gnumake
    sops
    ssh-to-age
  ];
}
