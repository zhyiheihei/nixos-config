{
  lib,
  pkgs,
  ...
}:
{
  imports = [
    ../../nixos/client.nix
    ../../nixos/optional-apps/nix-distributed.nix

    ./hardware-configuration.nix
  ];

  boot.loader.grub = {
    efiSupport = true;
    device = "nodev";
  };

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
