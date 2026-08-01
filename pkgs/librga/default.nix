{ stdenv, lib, meson, ninja, fetchFromGitHub }:

# librga (Rockchip 2D Raster Graphic Acceleration) userland library.
#
# Pin the same commit nyanmisaka/jellyfin-ffmpeg uses for its RK3588
# zero-copy pipeline (builder/scripts.d/50-rkrga.sh). Static build, with the
# meson target rewritten from shared_library to library exactly like the
# upstream build script does.
stdenv.mkDerivation rec {
  pname = "librga";
  version = "jellyfin-rga-next-571a880";

  src = fetchFromGitHub {
    owner = "nyanmisaka";
    repo = "rk-mirrors";
    rev = "571a880951583a3b2a04e7e1fa900861653befde";
    sha256 = "0m7vb9hv1x647lny1narm7289psq59ymwm2mg1c3g71f32czzcsv";
  };

  nativeBuildInputs = [
    meson
    ninja
  ];

  preConfigure = ''
    sed -i 's/shared_library/library/g' meson.build
  '';

  mesonFlags = [
    "--buildtype=release"
    "--default-library=static"
    "-Dcpp_args=-fpermissive"
    "-Dlibdrm=false"
    "-Dlibrga_demo=false"
  ];

  postInstall = ''
    substituteInPlace "$out/lib/pkgconfig/librga.pc" \
      --replace-fail 'Libs: -L''${libdir} -lrga -pthread' \
        'Libs: -L''${libdir} -lrga -pthread -lstdc++ -lm'
    echo 'Libs.private: -lstdc++ -lm' >> "$out/lib/pkgconfig/librga.pc"
  '';

  meta = {
    description = "Rockchip 2D Raster Graphic Acceleration library (jellyfin fork)";
    homepage = "https://github.com/nyanmisaka/rk-mirrors";
    license = lib.licenses.asl20;
    platforms = [ "aarch64-linux" ];
  };
}
