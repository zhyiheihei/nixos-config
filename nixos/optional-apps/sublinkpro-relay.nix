{
  lib,
  LT,
  ...
}:
let
  upstream = "xsus1.ilbfhu.cn";
  subscriptionPath = "/wm4YAhsRMQjn5Uwf";
  allowedSources = [
    LT.hosts.greencloud.ltnet.IPv4
    LT.hosts.greencloud.ltnet.IPv6
    "127.0.0.1"
    "::1"
  ];
in
{
  lantian.firewall.zones = {
    LAN.tcpPorts."${LT.portStr.SublinkProRelay}".type = "local";
    LTNET.tcpPorts."${LT.portStr.SublinkProRelay}".type = "local";
  };

  lantian.nginxVhosts."sublinkpro-relay" = {
    accessibleBy = "private";
    listenHTTP = {
      enable = true;
      port = LT.port.SublinkProRelay;
    };
    listenHTTPS.enable = false;
    locations."= ${subscriptionPath}" = {
      proxyPass = "https://${upstream}";
      proxyOverrideHost = upstream;
      extraConfig = ''
        ${lib.concatMapStringsSep "\n" (source: "allow ${source};") allowedSources}
        deny all;

        proxy_ssl_server_name on;
        proxy_ssl_name ${upstream};

        limit_except GET {
          deny all;
        }
      '';
    };
  };
}
