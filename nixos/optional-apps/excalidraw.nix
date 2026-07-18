{ LT, config, ... }:
{
  virtualisation.oci-containers.containers.excalidraw = {
    image = "docker.io/excalidraw/excalidraw:latest";
    labels."io.containers.autoupdate" = "registry";
    ports = [ "127.0.0.1:${LT.portStr.Excalidraw}:80" ];
  };

  lantian.nginxVhosts = {
    "excalidraw.${config.networking.hostName}.zhyi.cc" = {
      locations."/" = {
        proxyPass = "http://127.0.0.1:${LT.portStr.Excalidraw}";
        enableOAuth = true;
      };
      accessibleBy = "private";
      sslCertificate = "lets-encrypt-${config.networking.hostName}.zhyi.cc";
      noIndex.enable = true;
    };
    "excalidraw.localhost" = {
      listenHTTP.enable = true;
      listenHTTPS.enable = false;
      locations."/".proxyPass = "http://127.0.0.1:${LT.portStr.Excalidraw}";
      accessibleBy = "localhost";
      noIndex.enable = true;
    };
  };
}
