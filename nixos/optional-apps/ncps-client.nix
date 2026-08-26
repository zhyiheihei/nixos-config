{
  LT,
  lib,
  ...
}:
let
  ncpsUrl = "http://${LT.hosts.opi5p.interconnect.IPv4}:${LT.portStr.Ncps}";
in
{
  # NCPS 统一代理所有上游缓存（attic.zhyi.xin、attic.xuyh0120.win、
  # cachix、国内镜像等），客户端只需连 NCPS 一个入口，不直连任何 attic。
  # 对齐上游 ncps-client 的单 substituter 模式；NCPS 地址跟随
  # hosts/opi5p/host.nix 的 interconnect.IPv4，替代上游硬编码的 192.168.0.4。
  nix.settings.substituters = lib.mkForce [ ncpsUrl ];

  # http 明文 substituter 必须同时出现在 trusted-substituters 里，否则 nix
  # 出于安全策略会把它标记为 disabled。NCPS 透传上游缓存的签名
  # （cache.nixos.org-1 等），对应公钥已在 trusted-public-keys 里。
  nix.settings.trusted-substituters = lib.mkForce [ ncpsUrl ];
}
