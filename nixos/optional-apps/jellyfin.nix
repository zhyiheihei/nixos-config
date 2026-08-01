{ LT, ... }:
let
  backend = "http://${LT.hosts.opi5p.interconnect.IPv4}";
  backendHost = "jellyfin-backend.opi5p.zhyi.cc";
  proxyLocation = {
    proxyPass = backend;
    proxyOverrideHost = backendHost;
    proxyWebsockets = true;
    proxyNoTimeout = true;
  };
in
{
  # Keep the public TLS endpoint on ml-home-vm, where the router forwards
  # ports 80/443 for all home services. Only Jellyfin's application backend
  # moves to OPI5P; changing the router's DNAT target would break the other
  # public virtual hosts on this machine.
  lantian.nginxVhosts = {
    "jellyfin.zhyi.xin" = {
      locations."/" = proxyLocation;
      sslCertificate = "lets-encrypt-zhyi.xin";
      noIndex.enable = true;
    };

    "jellyfin.localhost" = {
      listenHTTP.enable = true;
      listenHTTPS.enable = false;
      locations."/" = proxyLocation;
      noIndex.enable = true;
      accessibleBy = "localhost";
    };
  };
}
