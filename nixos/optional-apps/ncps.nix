{
  LT,
  config,
  lib,
  ...
}:
{
  services.ncps = {
    enable = true;
    # 监听地址跟随本机 hosts/<host>/host.nix 的 interconnect.IPv4；
    # 上游硬编码的 192.168.0.4 是作者局域网地址，opi5p（.62）上 bind 失败
    # 导致 ncps 崩溃循环、全机群 substituter 不可用。
    server.addr = "${LT.this.interconnect.IPv4}:${LT.portStr.Ncps}";
    cache = {
      inherit (config.networking) hostName;
      lru.schedule = "53 4 * * *";
      maxSize = "100G";
      signNarinfo = false;
      upstream = {
        # 排除 attic 系上游：ncps 0.9.4 解析不了 attic/cachix 的非 hash 命名
        # NAR URL，命中即 500 不回退（kalbasit/ncps#1329）。这几个缓存由
        # 客户端 substituters 直连（ncps-client.nix），公钥已在常量里。
        urls =
          [ "https://cache.nixos.org" ]
          ++ lib.filter (u: !builtins.elem u LT.constants.nix.atticSubstituters) LT.constants.nix.substituters;
        publicKeys = LT.constants.nix.trusted-public-keys;
      };
    };
  };
}
