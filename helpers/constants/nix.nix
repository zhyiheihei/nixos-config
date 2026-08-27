{ inputs, ... }: rec {
  attic = rec {
    cacheName = "lantian";
    url = "https://attic.zhyi.xin/lantian";
    publicKey = "lantian:Pi7qMC8lIOrR8cTh4vfcRuSL/z+Bh5BAFYlEo/mbq2U=";
  };

  # Author's NUR binary caches (xddxdd/nur-packages exposes both attic and
  # cachix via flake `meta`). Keep ours + additionally pull the author's
  # caches for upstream packages.
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
    "https://mirrors.ustc.edu.cn/nix-channels/store"
    "https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store"
    "https://cache.nixos-cuda.org"
    "https://cuda-maintainers.cachix.org"
    "https://nix-gaming.cachix.org"
    "https://comfyui.cachix.org"
  ];
  trusted-public-keys = [
    attic.publicKey
    authorCachix.publicKey
    authorAttic.publicKey
    # SJTU / USTC / TUNA mirrors serve cache.nixos.org content, so the
    # official key must be trusted for their substitutes to be accepted.
    "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
    "cache.nixos-cuda.org:74DUi4Ye579gUqzH4ziL9IyiJBlDpMRn9MBN8oNan9M="
    "cuda-maintainers.cachix.org-1:0dq3bujKpuEPMCX6U4WylrUDZ9JyUG0VpVZa7CNfq5E="
    "nix-gaming.cachix.org-1:nbjlureqMbRAxR1gJ/f3hxemL9svXaZF/Ees8vCUUs4="
    "comfyui.cachix.org-1:33mf9VzoIjzVbp0zwj+fT51HG0y31ZTK3nzYZAX0rec="
  ];
}
