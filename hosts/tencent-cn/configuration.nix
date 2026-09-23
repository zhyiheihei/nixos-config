{ ... }:
{
  imports = [
    ../../nixos/server.nix

    ./hardware-configuration.nix
  ];

  systemd.network.networks.eth0 = {
    matchConfig.Name = "eth0";
    # Tencent gives the public IPv6 as a static /128; the gateway is the
    # subnet router's fixed link-local (Shanghai CVMs use a fixed gateway,
    # unlike Seoul CVMs where it is derived from the instance MAC), and no
    # RA default route is advertised (accept_ra stays off).
    address = [ "2402:4e00:c032:6100:4678:c7be:842a:0/128" ];
    routes = [
      {
        Destination = "::/0";
        Gateway = "fe80::feee:ffff:feff:ffff";
        GatewayOnLink = true;
      }
    ];
    networkConfig = {
      DHCP = "ipv4";
      IPv6AcceptRA = "no";
    };
  };

  boot.kernelParams = [ "console=ttyS0,115200" ];

  # The mesh default vhost carries snakeoil by default; use the wildcard
  # certificate synced from greencloud so public TLS verifies without a
  # per-host issuance round-trip (same choice as tencent).
  lantian.nginxVhosts."tencent-cn.zhyi.xin".sslCertificate = "lets-encrypt-zhyi.xin";
}
