{
  LT,
  lib,
  ...
}:
let
  ncpsUrl = "http://${LT.hosts.dragon-q8b.interconnect.IPv4}:${LT.portStr.Ncps}";
in
{
  # NCPS 是全机群唯一 substituter 入口（cache.nixos.org + attic 系缓存全部
  # 作为它的上游合并；2026-09-03 起 ncps 用上游 flake，非 hash NAR URL 已
  # 修复）。http 明文 substituter 必须同时出现在 trusted-substituters 里，
  # 否则 nix 出于安全策略会把它标记为 disabled。NCPS 透传上游缓存的签名，
  # 对应公钥已在常量 trusted-public-keys 里。
  nix.settings.substituters = lib.mkForce [ ncpsUrl ];
  nix.settings.trusted-substituters = lib.mkForce [ ncpsUrl ];
}
