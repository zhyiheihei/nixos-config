{ inputs, ... }:
rec {
  substituters = [
    inputs.nur-xddxdd.meta.cachixUrl
    "https://cache.nixos-cuda.org"
    "https://cuda-maintainers.cachix.org"
    "https://nix-gaming.cachix.org"
    "https://comfyui.cachix.org"
    "https://cache.numtide.com"
    "https://cache.nixos-cuda.org"
    "https://cache.flox.dev"
  ];
  trusted-public-keys = [
    inputs.nur-xddxdd.meta.cachixPublicKey
    "cache.nixos-cuda.org:74DUi4Ye579gUqzH4ziL9IyiJBlDpMRn9MBN8oNan9M="
    "cuda-maintainers.cachix.org-1:0dq3bujKpuEPMCX6U4WylrUDZ9JyUG0VpVZa7CNfq5E="
    "nix-gaming.cachix.org-1:nbjlureqMbRAxR1gJ/f3hxemL9svXaZF/Ees8vCUUs4="
    "comfyui.cachix.org-1:33mf9VzoIjzVbp0zwj+fT51HG0y31ZTK3nzYZAX0rec="
    "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
    "cache.nixos-cuda.org:74DUi4Ye579gUqzH4ziL9IyiJBlDpMRn9MBN8oNan9M="
    "flox-cache-public-1:7F4OyH7ZCnFhcze3fJdfyXYLQw/aV7GEed86nQ7IsOs="
  ];
}
