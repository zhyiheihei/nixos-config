{
  config,
  LT,
  lib,
  ...
}:
{
  imports = [
    ../../nixos/server.nix

    ./hardware-configuration.nix
  ];

  boot.kernelParams = [ "console=ttyS0,115200" ];

  systemd.network.networks.eth0 = {
    matchConfig.Name = "eth0";
    networkConfig.DHCP = "ipv4";
  };

  networking.nameservers = [
    "8.8.8.8"
    "8.8.4.4"
    "1.1.1.1"
  ];

  # Terminate the authentication origins on the public host, as in the
  # upstream public-facing layout. Other origins remain TLS passthrough.
  lantian.nginxVhosts = {
    "login.zhyi.xin" = {
      advertiseHTTP3 = false;
      locations."/" = {
        proxyPass = "https://${LT.hosts.colocrossing.ltnet.IPv4}:${LT.portStr.HTTPS}";
        extraConfig = ''
          proxy_ssl_name login.zhyi.xin;
          proxy_ssl_server_name on;
        '';
      };
      sslCertificate = "lets-encrypt-zhyi.xin";
      noIndex.enable = true;
    };

    "id.zhyi.xin" = {
      advertiseHTTP3 = false;
      locations."/" = {
        proxyPass = "https://${LT.hosts.colocrossing.ltnet.IPv4}:${LT.portStr.HTTPS}";
        extraConfig = ''
          proxy_ssl_name id.zhyi.xin;
          proxy_ssl_server_name on;
        '';
      };
      sslCertificate = "lets-encrypt-zhyi.xin";
      noIndex.enable = true;
    };
  };

  services.nginx.virtualHosts = lib.mkForce (
    lib.mapAttrs (_: v: v._config) (
      lib.getAttrs [
        "id.zhyi.xin"
        "login.zhyi.xin"
      ] config.lantian.nginxVhosts
    )
  );

  services.nginx.streamConfig = ''
    resolver 1.1.1.1 8.8.8.8 valid=60s ipv6=off;

    map $ssl_preread_server_name $https_origin {
      id.zhyi.xin 127.0.0.1:${LT.portStr.HTTPS};
      login.zhyi.xin 127.0.0.1:${LT.portStr.HTTPS};
      default ${LT.hosts.colocrossing.ltnet.IPv4}:443;
    }

    server {
      listen 0.0.0.0:443;
      listen [::]:443;
      ssl_preread on;
      proxy_connect_timeout 10s;
      proxy_timeout 3600s;
      proxy_pass $https_origin;
    }
  '';
}
