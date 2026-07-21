{
  LT,
  lib,
  ...
}:
{
  imports = [
    ../../nixos/server.nix

    ./hardware-configuration.nix
    ../../nixos/optional-apps/dex.nix
    ../../nixos/optional-apps/glauth.nix
    ../../nixos/optional-apps/pocket-id.nix
    ../../nixos/optional-apps/vaultwarden.nix
  ];

  boot.kernelParams = [ "console=ttyS0,115200" ];

  systemd.network.networks.eth0 = {
    matchConfig.Name = "eth0";
    networkConfig.DHCP = "ipv4";
  };

  networking.nameservers = [
    "223.5.5.5"
    "223.6.6.6"
    "119.29.29.29"
  ];

  lantian.nginxVhosts."cnvm.zhyi.cc".sslCertificate = "lets-encrypt-zhyi.cc";

  lantian.nginxVhosts."_default_https" = {
    sslCertificate = "lets-encrypt-zhyi.xin";
    locations."/" = {
      return = lib.mkForce null;
      proxyPass = "https://${LT.hosts.colocrossing.ltnet.IPv4}:443";
      proxyWebsockets = true;
      extraConfig = ''
        proxy_ssl_name $host;
        proxy_ssl_server_name on;
      '';
    };
  };

  lantian.nginxVhosts."zhyi.xin" = {
    root = lib.mkForce null;
    locations."/" = lib.mkForce {
      proxyPass = "https://${LT.hosts.colocrossing.ltnet.IPv4}:443";
      proxyWebsockets = true;
      extraConfig = ''
        proxy_ssl_name $host;
        proxy_ssl_server_name on;
      '';
    };
  };
}
