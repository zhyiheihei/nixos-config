{
  LT,
  config,
  ...
}:
let
  proxy = "http://${LT.this.interconnect.IPv4}:7892";
  brokenNcpsUpstreams = [
    LT.nix.attic.url
    # USTC can publish a valid narinfo before the referenced NAR is available.
    # ncps stores that metadata, fails to fetch the NAR, purges the entry and
    # responds with HTTP 500, which makes Nix disable the whole local cache.
    "https://mirrors.ustc.edu.cn/nix-channels/store"
    # TUNA can return a valid narinfo followed by HTTP 403 for its NAR.
    # ncps then purges the incomplete entry and returns HTTP 500.
    "https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store"
  ];
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
          builtins.filter (
            url: !(builtins.elem url brokenNcpsUpstreams)
          ) LT.constants.nix.substituters
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
