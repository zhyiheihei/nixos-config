{ lib, LT, ... }:
{
  imports = [
    ../../nixos/server.nix

    ./hardware-configuration.nix
    ../../nixos/optional-apps/hubproxy.nix
    ../../nixos/optional-apps/metapi.nix
    ../../nixos/optional-apps/searxng.nix
    ../../nixos/optional-apps/uni-api.nix
  ];

  lantian.hubproxy.enable = true;

  # Docker/GitHub/HuggingFace acceleration for LTNET devices. Private only:
  # resolves via hub.ltnet.zhyi.cc to tencent's ZeroTier/LTNET address
  # (198.18.0.128); the vhost rejects non-reserved source addresses, so the
  # public internet can never use it as a free mirror.
  lantian.nginxVhosts."hub.ltnet.zhyi.cc" = {
    locations."/" = {
      proxyPass = "http://127.0.0.1:${LT.portStr.HubProxy}";
      proxyNoTimeout = true;
    };

    sslCertificate = "lets-encrypt-hub.ltnet.zhyi.cc";
    accessibleBy = "private";
    noIndex.enable = true;
  };

  boot.kernelParams = [ "console=ttyS0,115200" ];

  systemd.network.networks.eth0 = {
    matchConfig.Name = "eth0";
    # Tencent gives the public IPv6 as a static /128; the gateway is the
    # subnet router's link-local (derived from MAC fe:ee:6c:22:4a:de) and
    # no RA default route is advertised (accept_ra stays off).
    address = [ "240d:c000:f05f:8900:4678:c7be:842a:0/128" ];
    routes = [
      {
        routeConfig = {
          Destination = "::/0";
          Gateway = "fe80::fcee:6cff:fe22:4ade";
          GatewayOnLink = true;
        };
      }
    ];
    networkConfig = {
      DHCP = "ipv4";
      IPv6AcceptRA = "no";
    };
  };

  # cn-accel is used for the v2ray exit; skip mihomo to save memory.
  lantian.mihomo.enable = false;

  # Serve /ray (v2ray xhttp) with a real certificate so cn-accel clients
  # can verify TLS; the wg-mesh-wstunnel default vhost only carries snakeoil.
  lantian.nginxVhosts."tencent.zhyi.cc".sslCertificate = "lets-encrypt-zhyi.cc";

  # Korea has no entry in the shared yggdrasil regionMappings
  # (nixos/common-apps/yggdrasil/default.nix); peer the closest regions
  # instead of editing the public module.
  services.yggdrasil.regions = [
    "japan"
    "singapore"
  ];
}
