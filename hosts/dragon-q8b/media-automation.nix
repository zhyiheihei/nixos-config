# 从 opi5p 迁入的 tachidesk + peerbanhelper。opi5p（RK3588/16G）同时跑
# Frigate NVR、Immich、HA 等 15+ 服务，kswapd0 持续 80%+ CPU、load1 超 800，
# 导致 ncps 和 node exporter 间歇性超时。dragon-q8b（SC8280XP/8G）当前
# 负载 0.02，有充足余量承接这两个 Java/Podman 服务。
{
  config,
  lib,
  LT,
  ...
}:
let
  activationMarker = "/nix/persistent/var/lib/media-automation/ready";
  gatedServices = [
    "peerbanhelper"
    "podman-tachidesk"
  ];
  proxyEnvironment = {
    HTTP_PROXY = "socks5://${LT.hosts.router.interconnect.IPv4}:${LT.portStr.V2Ray.SocksClient}";
    HTTPS_PROXY = "socks5://${LT.hosts.router.interconnect.IPv4}:${LT.portStr.V2Ray.SocksClient}";
    NO_PROXY = "localhost,127.0.0.1,::1,192.168.0.0/16,198.18.0.0/15,.zhyi.xin";
    http_proxy = "socks5://${LT.hosts.router.interconnect.IPv4}:${LT.portStr.V2Ray.SocksClient}";
    https_proxy = "socks5://${LT.hosts.router.interconnect.IPv4}:${LT.portStr.V2Ray.SocksClient}";
    no_proxy = "localhost,127.0.0.1,::1,192.168.0.0/16,198.18.0.0/15,.zhyi.xin";
  };
in
{
  imports = [
    ../../nixos/optional-apps/peerbanhelper.nix
    ../../nixos/optional-apps/tachidesk.nix
  ];

  systemd.services = lib.mkMerge [
    (lib.genAttrs gatedServices (_: {
      partOf = [ "media-automation.target" ];
      unitConfig.ConditionPathExists = activationMarker;
    }))
    {
      podman-tachidesk.environment = proxyEnvironment;
    }
  ];

  systemd.targets.media-automation = {
    description = "Dragon-Q8B media automation stack";
    wantedBy = [ "multi-user.target" ];
    unitConfig.ConditionPathExists = activationMarker;
    wants = map (name: "${name}.service") gatedServices;
    after = [ "network.target" ];
  };

  systemd.tmpfiles.settings.media-automation = {
    "/nix/persistent/var/lib/media-automation".d = {
      mode = "0700";
      user = "root";
      group = "root";
    };
  };
}
