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

    ../../nixos/optional-apps/pterodactyl.nix
  ];

  disabledModules = [ ../../nixos/server-apps/wg-mesh.nix ];

  lantian.pterodactyl.enable = true;

  lantian.nginxVhosts."map.mc.zhyi.xin" = {
    locations."/" = {
      proxyPass = "http://127.0.0.1:${LT.portStr.MinecraftMap}";
      proxyWebsockets = true;
      proxyNoTimeout = true;
    };

    sslCertificate = "lets-encrypt-mc.zhyi.xin";
    noIndex.enable = true;
  };

  networking.nameservers = lib.mkForce [ "192.168.0.1" ];

  lantian.firewall.zones = {
    WAN.ports."${LT.portStr.Minecraft}".type = "local";
    WAN.ports."${LT.portStr.MinecraftSecondary}".type = "local";
    WAN.ports."${LT.portStr.Pterodactyl.SFTP}".type = "local";
    LAN = {
      ports."${LT.portStr.Minecraft}".type = "local";
      ports."${LT.portStr.MinecraftSecondary}".type = "local";
      ports."${LT.portStr.Pterodactyl.SFTP}".type = "local";
      udpPorts."9993".type = "local";
    };
    LTNET.ports."${LT.portStr.Minecraft}".type = "local";
    LTNET.ports."${LT.portStr.MinecraftSecondary}".type = "local";
    LTNET.ports."${LT.portStr.Pterodactyl.SFTP}".type = "local";
  };

  systemd.tmpfiles.rules = [ "d /var/log/audit 0750 root root -" ];

  systemd.services.podman.environment = LT.proxyEnvironment;

  # 私有镜像凭据：pterodactyl/wings 用 podman 拉 ghcr.io/<owner>/zccfwq-server:<tag>，
  # 凭据得是 podman 认的 auth.json（整份 JSON 字符串），直接落到 podman 的默认路径。
  # 2026-11-27 迁 MCSM → pterodactyl 时这段被一并删掉，于是
  # /root/.config/containers/auth.json 成了悬空软链、podman 拉镜像 denied；现在补回来。
  # 值在 mcsm.yaml 的 ghcr_auth（已轮换为只读包 token）；文件名是历史债，暂不改名。
  sops.secrets.ghcr-auth = {
    sopsFile = LT.secret "mcsm.yaml";
    key = "ghcr_auth";
    path = "/root/.config/containers/auth.json";
  };

  environment.etc."containers/registries.conf.d/99-mirrors.conf".text = lib.mkForce ''
    [[registry]]
    location = "docker.io"

    [[registry.mirror]]
    location = "docker.1panel.live"

    [[registry.mirror]]
    location = "dockerproxy.net"

    [[registry]]
    location = "ghcr.io"

    [[registry.mirror]]
    location = "hub.tencent.zhyi.xin/ghcr.io"
  '';
}
