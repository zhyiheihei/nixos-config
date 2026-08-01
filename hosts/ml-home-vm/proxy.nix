{
  LT,
  ...
}:
let
  jellyfinProxy = "http://${LT.hosts.router.interconnect.IPv4}:${LT.portStr.V2Ray.SocksClient}";
  noProxy = "localhost,127.0.0.1,::1,192.168.0.0/16,.zhyi.cc,.zhyi.xin";
in
{
  # Jellyfin runs in an isolated netns where TMDB et al. are not directly
  # reachable; route metadata fetches through the router v2ray proxy.
  systemd.services.jellyfin.environment = {
    HTTP_PROXY = jellyfinProxy;
    HTTPS_PROXY = jellyfinProxy;
    NO_PROXY = noProxy;
    http_proxy = jellyfinProxy;
    https_proxy = jellyfinProxy;
    no_proxy = noProxy;
  };
}
