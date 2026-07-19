{
  LT,
  lib,
  pkgs,
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

  systemd.network.networks.wgmesh117.linkConfig.MTUBytes = lib.mkForce 1280;

  systemd.services.wg-mesh-wstunnel-jpvm = {
    description = "WireGuard mesh WebSocket tunnel to JPVM";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    script = ''
      exec ${pkgs.wstunnel}/bin/wstunnel client \
        --log-lvl WARN \
        --tls-verify-certificate \
        --http-upgrade-path-prefix ltnet-wg \
        --websocket-ping-frequency-sec 10 \
        -L 'udp://127.0.0.1:10119:127.0.0.1:10119?timeout_sec=0' \
        wss://jp.zhyi.cc:443
    '';
    serviceConfig = LT.serviceHarden // {
      DynamicUser = true;
      Restart = "always";
      RestartSec = 5;
    };
  };

  services.nginx.streamConfig = ''
    resolver 223.5.5.5 119.29.29.29 valid=60s ipv6=off;

    map $ssl_preread_server_name $https_origin {
      zhyi.xin 127.0.0.1:${LT.portStr.HTTPS};
      ~^.+\.zhyi\.xin$ 127.0.0.1:${LT.portStr.HTTPS};
      cnvm.zhyi.cc 127.0.0.1:${LT.portStr.HTTPS};
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

    server {
      listen 0.0.0.0:${LT.portStr.Matrix.Public};
      listen [::]:${LT.portStr.Matrix.Public};
      proxy_connect_timeout 10s;
      proxy_timeout 3600s;
      proxy_pass ${LT.hosts.colocrossing.ltnet.IPv4}:${LT.portStr.Matrix.Public};
    }
  '';
}
