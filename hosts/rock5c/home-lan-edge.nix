{ ... }:
let
  qnapAddress = "192.168.0.40";
in
{
  lantian.nginxVhosts = {
    "qnap.zhyi.xin" = {
      locations."/" = {
        proxyPass = "http://${qnapAddress}:8080";
        proxyWebsockets = true;
      };
      sslCertificate = "lets-encrypt-zhyi.xin";
      noIndex.enable = true;
    };
  };
}
