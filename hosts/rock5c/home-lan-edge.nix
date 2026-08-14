{ LT, ... }:
let
  qnapAddress = "192.168.0.40";
in
{
  networking.hosts."${LT.hosts.greencloud.ltnet.IPv4}" = [
    "axonhub.greencloud.zhyi.cc"
    "n8n-bridge.greencloud.zhyi.cc"
    "n8n.zhyi.xin"
    "openai-edge-tts.greencloud.zhyi.cc"
    "rsshub.zhyi.xin"
  ];

  # Services on tencent are reached over the ZeroTier/LTNET tunnel; resolve
  # them to tencent's LTNET address instead of the public IP.
  networking.hosts."${LT.hosts.tencent.ltnet.IPv4}" = [
    "hub.tencent.zhyi.cc"
    "metapi.tencent.zhyi.cc"
    "prometheus.tencent.zhyi.cc"
  ];

  lantian.nginxVhosts = {
    "qnap.zhyi.xin" = {
      locations."/" = {
        proxyPass = "http://${qnapAddress}:8080";
        proxyWebsockets = true;
      };
      sslCertificate = "lets-encrypt-zhyi.xin";
      noIndex.enable = true;
    };

    "couchdb.zhyi.xin" = {
      locations."/".proxyPass = "http://${qnapAddress}:5984";
      sslCertificate = "lets-encrypt-zhyi.xin";
      noIndex.enable = true;
    };
  };
}
