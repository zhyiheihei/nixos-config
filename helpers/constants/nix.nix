{ inputs, ... }: rec {
  attic = rec {
    cacheName = "lantian";
    url = "https://attic.zhyi.xin/lantian";
    publicKey = "lantian:Pi7qMC8lIOrR8cTh4vfcRuSL/z+Bh5BAFYlEo/mbq2U=";
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

  # ncps（nixpkgs 0.9.4）无法解析非 hash 命名的上游 NAR URL：attic 系用
  # nar/<store-path-hash>.nar，cachix 新版用 nar/<uuid>.nar.zst，命中即 500
  # 且不回退（kalbasit/ncps#1329）。ncps 上游必须排除这三个，由客户端
  # substituters 直连（见 ncps-client.nix / ncps.nix）。
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