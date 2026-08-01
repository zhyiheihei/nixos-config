{ stdenv, lib, cmake, fetchFromGitHub }:

# Rockchip MPP (Media Process Platform) userland library.
#
# Pin the same commit nyanmisaka/jellyfin-ffmpeg uses for its RK3588
# zero-copy pipeline (builder/scripts.d/50-rkmpp.sh). The static build is
# required so that jellyfin-ffmpeg links MPP directly into the binary.
stdenv.mkDerivation rec {
  pname = "rockchip-mpp";
  version = "jellyfin-mpp-next-48fb6aa";

  src = fetchFromGitHub {
    owner = "nyanmisaka";
    repo = "mpp";
    rev = "48fb6aa79c8b48e1ca98ced18233fcd8a6ac68c5";
    sha256 = "0fy8dpmcjdipqyy6l113vfhmxpj8a9mns3kp0y8hrqvjiazmiknk";
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
      --replace-fail 'Libs: -L''${libdir} -lrockchip_mpp' \
        'Libs: -L''${libdir} -lrockchip_mpp -lstdc++ -lm' \
      --replace-fail 'Libs.private:' 'Libs.private: -lstdc++ -lm'
  '';

  meta = {
    description = "Rockchip Media Process Platform userland library (jellyfin fork)";
    homepage = "https://github.com/nyanmisaka/mpp";
    license = lib.licenses.asl20;
    platforms = [ "aarch64-linux" ];
  };
}
