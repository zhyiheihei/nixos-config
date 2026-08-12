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
  # Keep VaultS3 on the LAN path instead of the public home-DDNS hairpin,
  # which is flaky from this host.
  networking.hosts."${LT.hosts.opi5p.interconnect.IPv4}" = [ "vaults3.zhyi.cc" ];

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
