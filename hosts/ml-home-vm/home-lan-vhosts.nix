{ LT, ... }:
let
  qnapAddress = "192.168.2.93";
in
{
  networking.hosts.${LT.this.interconnect.IPv4} = [ "vaults3.zhyi.cc" ];

  lantian.nginxVhosts = {
    "vaults3.zhyi.cc" = {
      locations."/" = {
        proxyPass = "http://${qnapAddress}:9000";
        proxyOverrideHost = "$http_host";
        proxyNoTimeout = true;
      };
      sslCertificate = "lets-encrypt-zhyi.cc";
      noIndex.enable = true;
    };

    "qnap.zhyi.cc" = {
      locations."/" = {
        proxyPass = "http://${qnapAddress}:8080";
        proxyWebsockets = true;
      };
      sslCertificate = "lets-encrypt-zhyi.cc";
      noIndex.enable = true;
    };

    "couchdb.zhyi.cc" = {
      locations."/".proxyPass = "http://${qnapAddress}:5984";
      sslCertificate = "lets-encrypt-zhyi.cc";
      noIndex.enable = true;
    };
  };
}
