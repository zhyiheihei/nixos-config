# Third-party notices

## liquid-glass-studio

- Source: https://github.com/iyinchao/liquid-glass-studio
- License: MIT (see `LICENSE` in this directory)
- Used for: the WebGPU liquid glass renderer (`assets/js/studio-glass.js`
  driver + `assets/js/studio-glass-webgpu.js` WGSL backend) and the
  reference shader math in `reference/liquid-glass-studio/` (local-only
  reference checkout for audit comparison, never committed per `.gitignore`).

## html2canvas-pro

- Package: `html2canvas-pro` 1.5.8
- Source: https://github.com/niklasvh/html2canvas-pro
- License: MIT
- SRI: `sha256-Vv/S7gkGXkDiEGi19tbFIzccVh/PxqBKcYbE1H5mEPM=` — kept in sync
  across `default.nix` (fetchurl), `homepage-orchestrator.js` (loadScript
  integrity) and this file; a `default.nix` assertion enforces all three.
- Distribution: fetched at build time by `default.nix` with a fixed SRI hash
  and served from `/homepage-assets/vendor/` with immutable caching.

Both projects are used under their MIT licenses. The full license texts are
kept next to this module (`LICENSE` for liquid-glass-studio) and in the
upstream `html2canvas-pro` package; this file records attribution and
provenance for audit purposes.
