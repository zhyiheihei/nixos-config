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
        # 2026-09-03 起用 ncps 上游 flake（>= 3a46da66），非 hash NAR URL
        # （attic/cachix，kalbasit/ncps#1329）已修复，attic 系缓存合并进
        # 上游，客户端只需指向 ncps 单一入口。cache.nixos.org 由
        # minimal-components/nix.nix 在客户端侧前置，不经常量传递。
        urls = [ "https://cache.nixos.org" ] ++ LT.constants.nix.substituters;
        publicKeys = LT.constants.nix.trusted-public-keys;
      };
    };
  };
}
