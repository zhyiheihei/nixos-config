{ inputs, ... }:
rec {
  attic = {
    cacheName = "zhyi";
    url = "https://attic.zhyi.xin/zhyi";
    publicKey = "zhyi:Pi7qMC8lIOrR8cTh4vfcRuSL/z+Bh5BAFYlEo/mbq2U=";
  };

  substituters = [
    attic.url
    inputs.nur-xddxdd.meta.cachixUrl
    inputs.nur-xddxdd.meta.atticUrl
    "https://cache.nixos-cuda.org"
    "https://cuda-maintainers.cachix.org"
    "https://nix-gaming.cachix.org"
    "https://comfyui.cachix.org"
    "https://cache.numtide.com"
    "https://lab.pve-epyc.xuyh0120.win/nix-static-file-cache"
  ];
  trusted-public-keys = [
    attic.publicKey
    inputs.nur-xddxdd.meta.cachixPublicKey
    inputs.nur-xddxdd.meta.atticPublicKey
    "cache.nixos-cuda.org:74DUi4Ye579gUqzH4ziL9IyiJBlDpMRn9MBN8oNan9M="
    "cuda-maintainers.cachix.org-1:0dq3bujKpuEPMCX6U4WylrUDZ9JyUG0VpVZa7CNfq5E="
    "nix-gaming.cachix.org-1:nbjlureqMbRAxR1gJ/f3hxemL9svXaZF/Ees8vCUUs4="
    "comfyui.cachix.org-1:33mf9VzoIjzVbp0zwj+fT51HG0y31ZTK3nzYZAX0rec="
    "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
    "nix-static-file-cache:JgdHxMl9VeWHOOULaTBnsWYJg57hYhJ76ALbNOvTe1s="
  ];
}
