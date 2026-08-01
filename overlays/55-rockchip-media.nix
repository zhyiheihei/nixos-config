{ inputs, ... }:
final: prev:
let
  inherit (final.stdenv.hostPlatform) isAarch64;
in
{
  # Rockchip RK3588 media stack: MPP + RGA userland libraries and a
  # jellyfin-ffmpeg with RKMPP/RKRGA enabled. Only relevant on aarch64.
  rockchip-mpp = final.callPackage ../pkgs/rockchip-mpp { };
  librga = final.callPackage ../pkgs/librga { };

  jellyfin-ffmpeg =
    if isAarch64 then
      (prev.jellyfin-ffmpeg.overrideAttrs (old: {
        buildInputs = old.buildInputs ++ [
          final.rockchip-mpp
          final.librga
        ];
        configureFlags = old.configureFlags ++ [
          "--enable-rkmpp"
          "--enable-rkrga"
        ];
      }))
    else
      prev.jellyfin-ffmpeg;
}
