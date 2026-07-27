{ ... }:
{
  imports = [
    ../../nixos/hardware/disable-watchdog.nix
    ../nanopi-r5c/hardware-configuration.nix
  ];
}
