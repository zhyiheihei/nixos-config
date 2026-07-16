{ lib, pkgs, ... }:
let
  pvePerl = pkgs.perl.withPackages (_: [ pkgs.pve-manager ]);
in
{
  imports = [ ../hardware/vfio.nix ];

  services.proxmox-ve.enable = true;

  # PVE starts restore helpers from pvedaemon's isolated PATH.
  systemd.services.pvedaemon.path = [ pkgs.e2fsprogs ];

  # proxmox-nixos does not import its optional container module by default.
  # PVE invokes this unit when starting an LXC container through pct.
  systemd.services."pve-container@" = {
    description = "PVE LXC Container: %i";
    path = [
      pvePerl
      pkgs.binutils
      pkgs.iproute2
      pkgs.lxc
    ];
    unitConfig = {
      DefaultDependencies = false;
      Documentation = "man:lxc-start man:lxc man:pct";
    };
    serviceConfig = {
      Delegate = true;
      ExecStart = "${pkgs.lxc}/bin/lxc-start -F -n %i";
      ExecStop = "${pkgs.pve-container}/share/lxc/pve-container-stop-wrapper %i";
      KillMode = "mixed";
      StandardError = "file:/run/pve/ct-%i.stderr";
      StandardOutput = "null";
      TimeoutStopSec = 120;
      Type = "simple";
    };
  };

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
