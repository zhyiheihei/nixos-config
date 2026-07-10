_: rec {
  attic = rec {
    cacheName = "lantian";
    url = "https://attic.zhyi.cc:4000/lantian";
    publicKey = "lantian:Pi7qMC8lIOrR8cTh4vfcRuSL/z+Bh5BAFYlEo/mbq2U=";
  };

  substituters = [
    "https://cache.nixos-cuda.org"
    "https://cuda-maintainers.cachix.org"
    "https://nix-gaming.cachix.org"
    "https://comfyui.cachix.org"
  ];
  trusted-public-keys = [
    "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
    "cache.nixos.org-1:6NCHdD59X431o0gWJ0qOeuKX2w8VxlNjY36Heq3v4F4="
    "cache.nixos-cuda.org:74DUi4Ye579gUqzH4ziL9IyiJBlDpMRn9MBN8oNan9M="
    "cuda-maintainers.cachix.org-1:0dq3bujKpuEPMCX6U4WylrUDZ9JyUG0VpVZa7CNfq5E="
    "nix-gaming.cachix.org-1:nbjlureqMbRAxR1gJ/f3hxemL9svXaZF/Ees8vCUUs4="
    "comfyui.cachix.org-1:33mf9VzoIjzVbp0zwj+fT51HG0y31ZTK3nzYZAX0rec="
  ];
}
