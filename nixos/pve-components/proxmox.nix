{ lib, pkgs, ... }:
{
  imports = [ ../hardware/vfio.nix ];

  services.proxmox-ve.enable = true;

  # PVE starts restore helpers from pvedaemon's isolated PATH.
  systemd.services.pvedaemon.path = [ pkgs.e2fsprogs ];

  systemd.services.pvescheduler.serviceConfig = {
    Restart = "always";
    RestartSec = 5;
  };
  systemd.services.qmeventd.serviceConfig = {
    Restart = "always";
    RestartSec = 5;
  };

  zramSwap.enable = lib.mkForce false;
}
