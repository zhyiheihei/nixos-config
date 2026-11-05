{
  lib,
  config,
  LT,
  ...
}:
let
  publicHttpsPort = 8443;
  with8443 =
    v:
    let
      cfg = v._config;
      baseListen = cfg.listen;
      existing = baseListen.content or baseListen;
      hasTLS = lib.any (l: lib.elem "ssl" (l.extraParameters or [ ])) existing;
    in
    if hasTLS then
      cfg
      // {
        listen = lib.mkForce (
          existing
          ++ [
            {
              addr = "0.0.0.0";
              port = publicHttpsPort;
              extraParameters = [ "ssl" ];
            }
          ]
        );
      }
    else
      cfg;
in
{
  imports = [
    ../../nixos/server.nix

    ../../nixos/optional-apps/nginx-openspeedtest.nix
    ../../nixos/optional-apps/tachidesk.nix
    ../../nixos/optional-apps/netns-tnl-buyvm.nix
    ../../nixos/optional-apps/ncps.nix

    # ../../nixos/optional-apps/palworld.nix 暂时不启用

    ./hardware-configuration.nix
    ./media-automation.nix
    ./edge-front.nix
    ./migrated-services.nix
  ];

  lantian.backup.enable = true;

  services.nginx.virtualHosts = lib.mkForce (lib.mapAttrs (_: with8443) config.lantian.nginxVhosts);

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

  # ncps 抓上游走本机 metacubexd mihomo mixed 口（7892，模块强制 allow-lan）。
  # 不复用 LT.proxyEnvironment 的 opi5p xray：家宽出境抖动时那条链路会大量
  # transport error。NO_PROXY 里不能放 .zhyi.xin，否则 cache.zhyi.xin 变直连并
  # 反复被判 unhealthy；只留 LAN 本地更快的 lab.opi5p 例外。
  systemd.services.ncps.environment = LT.proxyEnvironment // {
    HTTP_PROXY = "http://${LT.this.interconnect.IPv4}:7892";
    HTTPS_PROXY = "http://${LT.this.interconnect.IPv4}:7892";
    http_proxy = "http://${LT.this.interconnect.IPv4}:7892";
    https_proxy = "http://${LT.this.interconnect.IPv4}:7892";
    NO_PROXY = "localhost,127.0.0.1,::1,192.168.0.0/16,198.18.0.0/15,lab.opi5p.zhyi.xin,.m-team.cc,.m-team.io,api.m-team.io";
    no_proxy = "localhost,127.0.0.1,::1,192.168.0.0/16,198.18.0.0/15,lab.opi5p.zhyi.xin,.m-team.cc,.m-team.io,api.m-team.io";
  };
}
