{ LT, ... }:
let
  qnapAddress = "192.168.0.40";
in
{
  networking.hosts."${LT.hosts.colocrossing.ltnet.IPv4}" = [
    "axonhub.colocrossing.zhyi.cc"
    "metapi.colocrossing.zhyi.cc"
    "n8n-bridge.colocrossing.zhyi.cc"
    "n8n.zhyi.xin"
    "openai-edge-tts.colocrossing.zhyi.cc"
    "prometheus.colocrossing.zhyi.cc"
    "rsshub.zhyi.xin"
  ];

  lantian.nginxVhosts = {
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
