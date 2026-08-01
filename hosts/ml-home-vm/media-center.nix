{
  lib,
  LT,
  ...
}:
let
  edgeServices = [
    "bt"
    "pt"
    "seedbox"
    "sonarr"
    "radarr"
    "bazarr"
    "prowlarr"
    "jproxy"
    "peerbanhelper"
    "bitmagnet"
    "iyuu"
  ];
  mkProxyLocation = service: {
    proxyPass = "https://${service}.opi5p.zhyi.cc";
    proxyOverrideHost = "${service}.opi5p.zhyi.cc";
    proxyWebsockets = true;
    proxyNoTimeout = true;
  }
  // lib.optionalAttrs (builtins.elem service [
    "bt"
    "pt"
    "seedbox"
  ]) { allowCORS = true; };
  mkEdgeVhosts = service: [
    {
      name = "${service}.ml-home-vm.zhyi.cc";
      value = {
        locations."/" = mkProxyLocation service;
        accessibleBy = "private";
        sslCertificate =
          if service == "iyuu" then
            "lets-encrypt-ml-home-vm.zhyi.cc"
          else
            "zerossl-ml-home-vm.zhyi.cc";
        noIndex.enable = true;
      };
    }
    {
      name = "${service}.localhost";
      value = {
        listenHTTP.enable = true;
        listenHTTPS.enable = false;
        locations."/" = mkProxyLocation service;
        accessibleBy = "localhost";
        noIndex.enable = true;
      };
    }
  ];
  tachideskBackendHost = "tachidesk-backend.opi5p.zhyi.cc";
  tachideskProxyLocation = {
    proxyPass = "http://${LT.hosts.opi5p.interconnect.IPv4}";
    proxyOverrideHost = tachideskBackendHost;
    proxyWebsockets = true;
    proxyNoTimeout = true;
  };
in
{
  imports = [
    ../../nixos/client-components/hidpi.nix
    ../../nixos/client-components/xorg.nix

    ../../nixos/optional-apps/jellyfin.nix
  ];

  services.xserver.enable = lib.mkForce false;

  # The media writers now run exclusively on OPI5P. Keep the old private
  # URLs as stable edge endpoints, but never instantiate a second copy of the
  # downloaders, automation workers or their databases on this host again.
  lantian.nginxVhosts =
    builtins.listToAttrs (builtins.concatLists (map mkEdgeVhosts edgeServices))
    // {
      "tachidesk.zhyi.xin" = {
        locations."/" = tachideskProxyLocation // {
          enableBasicAuth = true;
        };
        sslCertificate = "lets-encrypt-zhyi.xin";
        noIndex.enable = true;
      };

      "tachidesk.localhost" = {
        listenHTTP.enable = true;
        listenHTTPS.enable = false;
        locations."/" = tachideskProxyLocation;
        accessibleBy = "localhost";
        noIndex.enable = true;
      };
    };
}
