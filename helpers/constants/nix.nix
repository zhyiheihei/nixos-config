{ inputs, ... }:
rec {
  attic = rec {
    # 2026-09-03 自 lantian 改名 zhyi：服务端复制 cache 行并保留同一
    # keypair（公钥值不变，仅签名/公钥的名字前缀变）。2026-09-05 全面
    # 转向 zhyi，lantian cache 已从服务端删除。
    cacheName = "zhyi";
    url = "https://attic.zhyi.xin/zhyi";
    publicKey = "zhyi:Pi7qMC8lIOrR8cTh4vfcRuSL/z+Bh5BAFYlEo/mbq2U=";
  };

  # Author's NUR binary caches (xddxdd/nur-packages exposes both attic and
  # cachix via flake `meta`).
  authorAttic = {
    url = inputs.nur-xddxdd.meta.atticUrl;
    publicKey = inputs.nur-xddxdd.meta.atticPublicKey;
  };
  authorCachix = {
    url = inputs.nur-xddxdd.meta.cachixUrl;
    publicKey = inputs.nur-xddxdd.meta.cachixPublicKey;
  };

  substituters = [
    attic.url
    authorCachix.url
    authorAttic.url
    "https://cache.nixos-cuda.org"
    "https://cuda-maintainers.cachix.org"
    "https://nix-gaming.cachix.org"
    "https://comfyui.cachix.org"
  ];

  # ncps（上游 flake，>= 3a46da66）已支持非 hash 命名的上游 NAR URL
  # （kalbasit/ncps#1329），attic 系缓存全部合并进 ncps 上游，此列表仅存
  # 于常量，客户端不再区分。
  atticSubstituters = [
    attic.url
    authorCachix.url
    authorAttic.url
  ];
  trusted-public-keys = [
    attic.publicKey
    authorCachix.publicKey
    authorAttic.publicKey
    "cache.nixos-cuda.org:74DUi4Ye579gUqzH4ziL9IyiJBlDpMRn9MBN8oNan9M="
    "cuda-maintainers.cachix.org-1:0dq3bujKpuEPMCX6U4WylrUDZ9JyUG0VpVZa7CNfq5E="
    "nix-gaming.cachix.org-1:nbjlureqMbRAxR1gJ/f3hxemL9svXaZF/Ees8vCUUs4="
    "comfyui.cachix.org-1:33mf9VzoIjzVbp0zwj+fT51HG0y31ZTK3nzYZAX0rec="
  ];
}
