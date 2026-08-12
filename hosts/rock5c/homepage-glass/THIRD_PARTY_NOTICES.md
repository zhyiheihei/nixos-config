# Third-party notices

## liquid-glass-studio

- Source: https://github.com/iyinchao/liquid-glass-studio
- License: MIT (see `LICENSE` in this directory)
- Used for: the WebGPU liquid glass renderer (`assets/js/studio-glass.js`
  driver + `assets/js/studio-glass-webgpu.js` WGSL backend) and the
  reference shader math in `reference/liquid-glass-studio/`.

## html2canvas-pro

- Package: `html2canvas-pro` 1.5.8
- Source: https://github.com/niklasvh/html2canvas-pro
- License: MIT
- Distribution: fetched at build time by `default.nix` with a fixed SRI hash
  and served from `/homepage-assets/vendor/` with immutable caching.

Both projects are used under their MIT licenses. The full license texts are
kept next to this module (`LICENSE` for liquid-glass-studio) and in the
upstream `html2canvas-pro` package; this file records attribution and
provenance for audit purposes.
