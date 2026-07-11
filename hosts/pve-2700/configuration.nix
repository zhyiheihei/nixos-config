{
  config,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    ../../nixos/pve.nix

    ./hardware-configuration.nix
  ];

  boot.loader.grub = {
    efiSupport = true;
    device = "nodev";
  };

  services.proxmox-ve.ipAddress = "192.168.2.11";

  networking.hosts = {
    "192.168.2.237" = [ config.networking.hostName ];
  };

  sops.age.sshKeyPaths = lib.mkForce [ "/etc/ssh/ssh_host_ed25519_key" ];

  services.openssh.settings = {
    PasswordAuthentication = lib.mkOverride 40 true;
    PermitRootLogin = lib.mkOverride 40 "yes";
  };

  environment.systemPackages = with pkgs; [
    age
    sops
    ssh-to-age
  ];
}
