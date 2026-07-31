{
  LT,
  config,
  ...
}:
let
  proxy = "http://${LT.this.interconnect.IPv4}:7892";
in
{
  services.ncps = {
    enable = true;
    server.addr = "${LT.this.interconnect.IPv4}:${LT.portStr.Ncps}";
    cache = {
      inherit (config.networking) hostName;
      dataPath = "/mnt/storage/.ncps";
      tempPath = "/mnt/storage/.ncps-tmp";
      upstream = {
        # Attic's streamed compressed NARs omit FileSize, which ncps rejects.
        # Clients use Attic directly before falling back to ncps for public caches.
        urls =
          builtins.filter (url: url != LT.nix.attic.url) LT.constants.nix.substituters
          ++ [ "https://cache.nixos.org" ];
        publicKeys = LT.constants.nix.trusted-public-keys;
      };
      lru.schedule = "53 4 * * *";
      maxSize = "100G";
      signNarinfo = false;
    };
  };

  systemd.services.ncps = {
    after = [ "podman-metacubexd.service" "mnt-storage.mount" ];
    wants = [ "podman-metacubexd.service" ];
    requires = [ "mnt-storage.mount" ];
    environment = {
      HTTP_PROXY = proxy;
      HTTPS_PROXY = proxy;
      NO_PROXY = "localhost,127.0.0.1,::1,192.168.0.0/16,.zhyi.cc,.zhyi.xin";
      http_proxy = proxy;
      https_proxy = proxy;
      no_proxy = "localhost,127.0.0.1,::1,192.168.0.0/16,.zhyi.cc,.zhyi.xin";
    };
  };
}
