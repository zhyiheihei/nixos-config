{
  LT,
  config,
  lib,
  ...
}:
let
  cfg = config.lantian.ncps;
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
  options.lantian.ncps = {
    dataPath = lib.mkOption {
      type = lib.types.str;
      default = "/mnt/storage/.ncps";
      description = "Persistent NCPS cache path";
    };
    tempPath = lib.mkOption {
      type = lib.types.str;
      default = "/mnt/storage/.ncps-tmp";
      description = "Temporary NCPS download path";
    };
    proxy = lib.mkOption {
      type = lib.types.str;
      default = "http://${LT.this.interconnect.IPv4}:7892";
      description = "HTTP proxy used for NCPS upstream downloads";
    };
    proxyUnit = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = "podman-metacubexd.service";
      description = "Optional local proxy unit ordered before NCPS";
    };
    storageUnit = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = "mnt-storage.mount";
      description = "Optional unit providing the NCPS cache filesystem";
    };
  };

  systemd.tmpfiles.settings.ncps = {
    "${cfg.dataPath}".d = {
      mode = "0750";
      user = "ncps";
      group = "ncps";
    };
    "${cfg.tempPath}".d = {
      mode = "0750";
      user = "ncps";
      group = "ncps";
    };
  };

  services.ncps = {
    enable = true;
    server.addr = "${LT.this.interconnect.IPv4}:${LT.portStr.Ncps}";
    cache = {
      inherit (config.networking) hostName;
      inherit (cfg) dataPath tempPath;
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
    after = lib.optionals (cfg.proxyUnit != null) [ cfg.proxyUnit ]
      ++ lib.optionals (cfg.storageUnit != null) [ cfg.storageUnit ];
    wants = lib.optionals (cfg.proxyUnit != null) [ cfg.proxyUnit ];
    requires = lib.optionals (cfg.storageUnit != null) [ cfg.storageUnit ];
    environment = {
      HTTP_PROXY = cfg.proxy;
      HTTPS_PROXY = cfg.proxy;
      NO_PROXY = "localhost,127.0.0.1,::1,192.168.0.0/16,.zhyi.cc,.zhyi.xin";
      http_proxy = cfg.proxy;
      https_proxy = cfg.proxy;
      no_proxy = "localhost,127.0.0.1,::1,192.168.0.0/16,.zhyi.cc,.zhyi.xin";
    };
  };
}
