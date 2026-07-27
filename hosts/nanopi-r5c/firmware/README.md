# NanoPi R5C boot firmware

`linux-u-boot-nanopi-r5c-current_26.08.0-trunk_arm64.deb` is the output of the
Armbian `nanopi-r5c` current U-Boot build used during the initial hardware
bring-up.

- U-Boot: `2026.01_armbian-2026.01-S127a-Pe8ca-H4faf-V942e-B5da4-R448a`
- DDR firmware: v1.21, final frequency 1560 MHz
- BL31: v1.44
- Debian package SHA-256:
  `3e27c8a04b665ecf28e49ff5866a26254e200330a7654bd550d19c463d5ae2b6`

The package is kept with the host definition so `sdImage` remains
self-contained and reproducible. `hardware-configuration.nix` extracts only
`idbloader.img` and `u-boot.itb`.

The Nixpkgs-built replacement tested on 2026-07-27 used U-Boot 2026.04, DDR
firmware v1.23 at 1056 MHz, and BL31 v1.45. It consistently stalled at about
3.16 seconds during Linux early device initialization, before either MMC
device appeared.
