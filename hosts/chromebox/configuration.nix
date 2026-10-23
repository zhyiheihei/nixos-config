{
  lib,
  config,
  LT,
  ...
}:
{
  imports = [
    ../../nixos/server.nix

    ../../nixos/optional-apps/ncps-client.nix

    ../../nixos/optional-apps/palworld.nix

    ./hardware-configuration.nix
    ./media-automation.nix
  ];

  lantian.backup.enable = true;

  boot.loader.grub = {
    efiSupport = true;
    device = "nodev";
  };

  systemd.network.networks."10-chromebox-lan" = {
    matchConfig.Name = "eno0";
    address = [ "${LT.this.interconnect.IPv4}/24" ];
    networkConfig.IPv6AcceptRA = "yes";
    routes = [
      {
        Destination = "0.0.0.0/0";
        Gateway = "192.168.0.1";
      }
    ];
  };
  networking.networkmanager.enable = lib.mkForce false;

  systemd.targets.network-online.wants = [ "systemd-networkd-wait-online@eno0.service" ];

  systemd.services.palworld-exporter.enable = false;

  systemd.services.palworld.serviceConfig.RestartSec = "5s";

  networking.hosts = {
    "${LT.this.interconnect.IPv4}" = [ config.networking.hostName ];
  };
}
