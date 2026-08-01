{ lib, ... }:
{
  imports = [
    ../../nixos/client-components/hidpi.nix
    ../../nixos/client-components/xorg.nix

    ../../nixos/optional-apps/jellyfin.nix
    ../../nixos/optional-apps/media-automation.nix
  ];

  services.xserver.enable = lib.mkForce false;
}
