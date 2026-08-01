{ inputs, ... }:
final: prev: {
  # Rockchip RK35 media stack: MPP + RGA userland libraries and a
  # jellyfin-ffmpeg with RKMPP/RKRGA enabled.  Keep the specialized FFmpeg
  # opt-in instead of replacing jellyfin-ffmpeg on every aarch64 host.
  rockchip-mpp = final.callPackage ../pkgs/rockchip-mpp { };
  librga = final.callPackage ../pkgs/librga { };
  libmali-rockchip-g610 = final.callPackage ../pkgs/libmali-rockchip-g610 { };

  jellyfin-ffmpeg-rockchip = prev.jellyfin-ffmpeg.overrideAttrs (old: {
    buildInputs = old.buildInputs ++ [
      final.rockchip-mpp
      final.librga
    ];
    configureFlags = old.configureFlags ++ [
      "--enable-rkmpp"
      "--enable-rkrga"
    ];
  });
}
