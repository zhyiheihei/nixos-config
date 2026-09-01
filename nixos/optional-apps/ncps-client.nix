{
  LT,
  lib,
  ...
}:
let
  ncpsUrl = "http://${LT.hosts.dragon-q8b.interconnect.IPv4}:${LT.portStr.Ncps}";
in
{
  # NCPS 统一代理 hash 命名 URL 的上游（cache.nixos.org、cuda、cachix 系），
  # attic 系三个缓存不进 ncps 上游（ncps 0.9.4 对其 NAR URL 解析 500，
  # kalbasit/ncps#1329），由客户端在此直连。ncps 404/未命中时 nix 顺序
  # 尝试后续 substituter，自有 attic 兑底。
  nix.settings.substituters = lib.mkForce ([ ncpsUrl ] ++ LT.constants.nix.atticSubstituters);

  # http 明文 substituter 必须同时出现在 trusted-substituters 里，否则 nix
  # 出于安全策略会把它标记为 disabled。NCPS 透传上游缓存的签名
  # （cache.nixos.org-1 等），对应公钥已在 trusted-public-keys 里。
  nix.settings.trusted-substituters = lib.mkForce ([ ncpsUrl ] ++ LT.constants.nix.atticSubstituters);
}
