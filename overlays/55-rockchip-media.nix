{ inputs, ... }:
final: prev: {
  # Rockchip RK35 media stack: MPP + RGA userland libraries and a
  # jellyfin-ffmpeg with RKMPP/RKRGA enabled.  Keep the specialized FFmpeg
  # opt-in instead of replacing jellyfin-ffmpeg on every aarch64 host.
  rockchip-mpp = final.callPackage ../pkgs/rockchip-mpp { };
  librga = final.callPackage ../pkgs/librga { };

  jellyfin-ffmpeg-rockchip = prev.jellyfin-ffmpeg.overrideAttrs (old: {
    buildInputs = old.buildInputs ++ [
      final.rockchip-mpp
      final.librga
    ];
    configureFlags = old.configureFlags ++ [
      # jellyfin-ffmpeg's official ARM64 builder links MPP and RGA statically
      # and exposes their C++ runtime through Libs.private.
      "--pkg-config-flags=--static"
      "--enable-rkmpp"
      "--enable-rkrga"
    ];
  });
}
