{
  inputs,
  lib,
  LT,
  ...
}:
{
  imports = [
    ../../nixos/server.nix

    ./hardware-configuration.nix

    inputs.venus-mainline.nixosModules.venus

    ../../nixos/optional-apps/mcsm.nix
  ];

  disabledModules = [ ../../nixos/server-apps/wg-mesh.nix ];

  lantian.mcsm.enable = true;

  virtualisation.oci-containers.containers.mcsm-web.ports = lib.mkForce [
    "${LT.this.interconnect.IPv4}:${LT.portStr.Mcsm.Web}:23333"
  ];

  networking.nameservers = lib.mkForce [ "192.168.0.1" ];

  lantian.firewall.zones.LAN.ports."${LT.portStr.Minecraft}".type = "local";

  systemd.tmpfiles.rules = [ "d /var/log/audit 0750 root root -" ];
  lantian.firewall.zones.LAN.udpPorts."9993".type = "local";

  environment.etc."containers/registries.conf.d/99-mirrors.conf".text = lib.mkForce ''
    [[registry]]
    location = "docker.io"

    [[registry.mirror]]
    location = "docker.1panel.live"

    [[registry.mirror]]
    location = "dockerproxy.net"
  '';
}
