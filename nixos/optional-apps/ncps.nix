{
  LT,
  config,
  ...
}:
{
  services.ncps = {
    enable = true;
    server.addr = "${LT.this.interconnect.IPv4}:${LT.portStr.Ncps}";
    upstream = {
      caches = LT.constants.nix.substituters ++ [ "https://cache.nixos.org" ];
      publicKeys = LT.constants.nix.trusted-public-keys;
    };
    cache = {
      inherit (config.networking) hostName;
      lru.schedule = "53 4 * * *";
      maxSize = "100G";
      signNarinfo = false;
    };
  };
}
