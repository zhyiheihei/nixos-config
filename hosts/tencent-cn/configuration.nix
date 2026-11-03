{
  LT,
  ...
}:
{
  imports = [
    ../../nixos/server.nix
    # 备案期间临时关闭 frps 对外服务
    # ../../nixos/optional-apps/frp.nix

    ./hardware-configuration.nix
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

  # 备案期间临时关闭对外 vhost
  # lantian.nginxVhosts."tencent-cn.zhyi.xin".sslCertificate = "lets-encrypt-zhyi.xin";

  # 备案期间临时关闭公网 Web 访问（保留 LTNET 访问）
  lantian.firewall.presets.public-firewall.firewalledPorts = [
    LT.port.HTTP
    LT.port.HTTPS
  ];
}
