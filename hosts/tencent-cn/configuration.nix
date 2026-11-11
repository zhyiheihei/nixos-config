{ inputs, lib, ... }:
{
  imports = [
    ../../nixos/server.nix
    ../../nixos/optional-apps/frp.nix

    ./hardware-configuration.nix

    ../../nixos/optional-apps/cliproxyapi.nix
    (inputs.secrets + "/cliproxyapi.nix")
    ../../nixos/optional-apps/dex.nix
    ../../nixos/optional-apps/halo.nix
    ../../nixos/optional-apps/pocket-id.nix
    ../../nixos/optional-apps/vaultwarden.nix
  ];

  systemd.network.networks.eth0 = {
    matchConfig.Name = "eth0";

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

  lantian.nginxVhosts."tencent-cn.zhyi.xin".sslCertificate = "lets-encrypt-zhyi.xin";

  lantian.nginxVhosts."bitwarden.zhyi.xin".accessibleBy = lib.mkForce "public";
}
