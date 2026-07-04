{
  lib,
  ...
}:
{
  imports = [
    ../../nixos/client.nix

    ./hardware-configuration.nix
  ];

  boot.loader.grub = {
    efiSupport = true;
    device = "nodev";
  };

  fileSystems."/" = lib.mkForce {
    device = "/dev/disk/by-uuid/02f9b911-0530-4f27-8355-23b22b25c071";
    fsType = "ext4";
  };

  sops.age.sshKeyPaths = lib.mkForce [ "/etc/ssh/ssh_host_ed25519_key" ];

  services.openssh.settings = {
    PasswordAuthentication = lib.mkOverride 40 true;
    PermitRootLogin = lib.mkOverride 40 "yes";
  };
}
