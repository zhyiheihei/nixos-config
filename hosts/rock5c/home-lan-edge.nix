{ LT, ... }:
let
  qnapAddress = "192.168.0.40";
in
{
  networking.hosts."${LT.hosts.greencloud.ltnet.IPv4}" = [
    "axonhub.greencloud.zhyi.cc"
    "metapi.greencloud.zhyi.cc"
    "n8n-bridge.greencloud.zhyi.cc"
    "n8n.zhyi.xin"
    "openai-edge-tts.greencloud.zhyi.cc"
    "prometheus.greencloud.zhyi.cc"
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
