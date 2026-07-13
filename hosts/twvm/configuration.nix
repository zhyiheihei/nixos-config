{ config, ... }:
{
  imports = [
    ../../nixos/server.nix

    ./hardware-configuration.nix
  ];

  systemd.network.networks.eth0 = {
    address = [
      "140.235.38.39/24"
      "2407:cdc0:f008:12a::/64"
    ];
    gateway = [
      "140.235.38.254"
      "fe80::1"
    ];
    linkConfig.RequiredForOnline = "routable";
    matchConfig.Name = "eth0";
  };

  networking.nameservers = [
    "10.10.10.10"
    "10.10.11.11"
    "1.1.1.1"
  ];

  lantian.nginxVhosts."tw.zhyi.cc".sslCertificate = "lets-encrypt-zhyi.cc";

  sops.templates.mihomo-subscription = {
    owner = "nginx";
    group = "nginx";
    mode = "0440";
    content = ''
      proxies:
        - name: twvm
          type: vless
          server: tw.zhyi.cc
          port: 8443
          uuid: ${config.sops.placeholder.v2ray-key}
          udp: true
          tls: true
          servername: tw.zhyi.cc
          client-fingerprint: firefox
          skip-cert-verify: false
          network: xhttp
          encryption: ""
          alpn:
            - h2
          xhttp-opts:
            path: /ray
            host: tw.zhyi.cc
            mode: stream-up
    '';
  };

  lantian.nginxVhosts."sub.zhyi.cc" = {
    sslCertificate = "lets-encrypt-zhyi.cc";
    locations."= /mihomo.yaml".extraConfig = ''
      default_type text/yaml;
      content_by_lua_block {
        local token_file = io.open("${config.sops.secrets.v2ray-key.path}", "r")
        if not token_file then
          return ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
        end

        local token = token_file:read("*a"):gsub("%s+$", "")
        token_file:close()
        if ngx.var.arg_token ~= token then
          return ngx.exit(ngx.HTTP_NOT_FOUND)
        end

        local subscription_file = io.open("${config.sops.templates.mihomo-subscription.path}", "r")
        if not subscription_file then
          return ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
        end

        ngx.print(subscription_file:read("*a"))
        subscription_file:close()
      }
    '';
  };
}
