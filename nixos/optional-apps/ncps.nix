{
  LT,
  config,
  ...
}:
{
  services.ncps = {
    enable = true;
    server.addr = "${LT.this.interconnect.IPv4}:${LT.portStr.Ncps}";
    cache = {
      inherit (config.networking) hostName;
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
}
