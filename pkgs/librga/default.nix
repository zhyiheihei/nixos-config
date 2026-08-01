{ stdenv, lib, meson, ninja, fetchFromGitHub }:

# librga (Rockchip 2D Raster Graphic Acceleration) userland library.
#
# Pin the exact commit used by jellyfin-ffmpeg's ARM64 builder
# (builder/scripts.d/50-rkrga.sh). Static build, with the
# meson target rewritten from shared_library to library exactly like the
# upstream build script does.
stdenv.mkDerivation rec {
  pname = "librga";
  version = "jellyfin-rga-next-1d330cc";

  src = fetchFromGitHub {
    owner = "nyanmisaka";
    repo = "rk-mirrors";
    rev = "1d330cc28551943bed3380261a5a9c6fbd58ff53";
    hash = "sha256-EO/YvkyaAgIyAZQJjXa8b5SEgCo4vfDpYoeKcJH1n4o=";
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
    echo 'Libs.private: -lstdc++' >> "$out/lib/pkgconfig/librga.pc"
  '';

  meta = {
    description = "Rockchip 2D Raster Graphic Acceleration library (jellyfin fork)";
    homepage = "https://github.com/nyanmisaka/rk-mirrors";
    license = lib.licenses.asl20;
    platforms = [ "aarch64-linux" ];
  };
}
