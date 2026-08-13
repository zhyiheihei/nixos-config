{ LT, ... }:
let
  qnapAddress = "192.168.0.40";
in
{
  networking.hosts = {
    "${LT.this.interconnect.IPv4}" = [ "vaults3.zhyi.cc" ];
    "${LT.hosts.greencloud.ltnet.IPv4}" = [
      "axonhub.greencloud.zhyi.cc"
      "metapi.greencloud.zhyi.cc"
      "n8n-bridge.greencloud.zhyi.cc"
      "n8n.zhyi.xin"
      "openai-edge-tts.greencloud.zhyi.cc"
      "rsshub.zhyi.xin"
    ];
  };

  lantian.nginxVhosts = {
    "vaults3.zhyi.cc" = {
      extraConfig = ''
        listen 0.0.0.0:8443 ssl;
        listen [::]:8443 ssl;
      '';
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
