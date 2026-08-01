{ stdenv, lib, cmake, fetchFromGitHub }:

# Rockchip MPP (Media Process Platform) userland library.
#
# Pin the exact commit used by jellyfin-ffmpeg's ARM64 builder
# (builder/scripts.d/50-rkmpp.sh). The static build matches upstream.
stdenv.mkDerivation rec {
  pname = "rockchip-mpp";
  version = "jellyfin-mpp-next-a9380ef";

  src = fetchFromGitHub {
    owner = "nyanmisaka";
    repo = "rk-mirrors";
    rev = "a9380ef333102ac318628f83b5f7a460d377749e";
    hash = "sha256-W18KrNdd1HNcubDv0K+CmAEdbXiqB5y0ECb0FUefUrk=";
  };

  nativeBuildInputs = [ cmake ];

  # The upstream helper is invoked directly by CMake and uses /bin/bash,
  # which does not exist inside a Nix build sandbox.
  postPatch = ''
    patchShebangs merge_static_lib.sh
  '';

  cmakeFlags = [
    "-DCMAKE_BUILD_TYPE=Release"
    "-DBUILD_TEST=OFF"
    "-DBUILD_SHARED_LIBS=OFF"
  ];

  postInstall = ''
    for pc in "$out/lib/pkgconfig/"*.pc; do
      substituteInPlace "$pc" \
        --replace-fail 'libdir=''${prefix}/'$out'/lib' "libdir=$out/lib" \
        --replace-fail 'includedir=''${prefix}/'$out'/include' "includedir=$out/include"
    done
    substituteInPlace "$out/lib/pkgconfig/rockchip_mpp.pc" \
      --replace-fail 'Libs.private:' 'Libs.private: -lstdc++'
  '';

  meta = {
    description = "Rockchip Media Process Platform userland library (jellyfin fork)";
    homepage = "https://github.com/nyanmisaka/mpp";
    license = lib.licenses.asl20;
    platforms = [ "aarch64-linux" ];
  };
}
