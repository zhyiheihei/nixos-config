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
        urls = LT.constants.nix.substituters ++ [ "https://cache.nixos.org" ];
        publicKeys = LT.constants.nix.trusted-public-keys;
      };
      lru.schedule = "53 4 * * *";
      maxSize = "100G";
      signNarinfo = false;
    };
  };
}
