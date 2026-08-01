{ stdenv, lib, meson, ninja, fetchFromGitHub }:

# librga (Rockchip 2D Raster Graphic Acceleration) userland library.
#
# Pin the exact commit used by jellyfin-ffmpeg's ARM64 builder
# (builder/scripts.d/50-rkrga.sh). Nix keeps the upstream shared-library target
# so FFmpeg can use the normal Nixpkgs dependency model and RPATH handling.
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

  mesonFlags = [
    "--buildtype=release"
    "--default-library=shared"
    "-Dcpp_args=-fpermissive"
    "-Dlibdrm=false"
    "-Dlibrga_demo=false"
  ];

  meta = {
    description = "Rockchip 2D Raster Graphic Acceleration library (jellyfin fork)";
    homepage = "https://github.com/nyanmisaka/rk-mirrors";
    license = lib.licenses.asl20;
    platforms = [ "aarch64-linux" ];
  };
}
