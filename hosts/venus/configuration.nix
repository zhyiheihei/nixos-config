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

  sops.secrets.mcsm-ghcr-auth = {
    sopsFile = LT.secret "mcsm.yaml";
    key = "ghcr_auth";
    path = "/root/.config/containers/auth.json";
  };

  lantian.nginxVhosts."map.mc.zhyi.xin" = {
    locations."/" = {
      proxyPass = "http://127.0.0.1:${LT.portStr.MinecraftMap}";
      proxyWebsockets = true;
      proxyNoTimeout = true;
    };

    sslCertificate = "lets-encrypt-mc.zhyi.xin";
    noIndex.enable = true;
  };

  virtualisation.oci-containers.containers.mcsm-daemon.ports = lib.mkForce [
    "127.0.0.1:${LT.portStr.Mcsm.Daemon}:24444"
    "10.88.0.1:${LT.portStr.Mcsm.Daemon}:24444"
  ];

  networking.nameservers = lib.mkForce [ "192.168.0.1" ];

  lantian.firewall.zones = {
    WAN.ports."${LT.portStr.Minecraft}".type = "local";
    LAN = {
      ports."${LT.portStr.Minecraft}".type = "local";
      udpPorts."9993".type = "local";
    };
    LTNET.ports."${LT.portStr.Minecraft}".type = "local";
  };

  systemd.tmpfiles.rules = [ "d /var/log/audit 0750 root root -" ];

  systemd.services.podman.environment = LT.proxyEnvironment;

  environment.etc."containers/registries.conf.d/99-mirrors.conf".text = lib.mkForce ''
    [[registry]]
    location = "docker.io"

    [[registry.mirror]]
    location = "docker.1panel.live"

    [[registry.mirror]]
    location = "dockerproxy.net"
  '';
}
