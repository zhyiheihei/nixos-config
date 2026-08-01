{
  autoPatchelfHook,
  dpkg,
  fetchurl,
  lib,
  libdrm,
  stdenv,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "libmali-rockchip-g610";
  version = "1.9-1-2131373";

  src = fetchurl {
    url = "https://github.com/tsukumijima/libmali-rockchip/releases/download/v${finalAttrs.version}/libmali-valhall-g610-g24p0-gbm_1.9-1_arm64.deb";
    hash = "sha256-2IGoCit2vBkyha9Ig0LxSnjvtPgGO/p0AR0w65lfI8Y=";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    dpkg
  ];
  buildInputs = [
    libdrm
    stdenv.cc.cc
  ];

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    dpkg-deb -x "$src" extracted
    debLib=extracted/usr/lib/aarch64-linux-gnu

    install -Dm644 "$debLib/libmali.so.1.9.0" "$out/lib/libmali.so.1.9.0"
    install -Dm644 "$debLib/libmali-hook.so.1.9.0" "$out/lib/libmali-hook.so.1.9.0"
    install -Dm644 "$debLib/mali/libMaliOpenCL.so.1" "$out/lib/libMaliOpenCL.so.1"
    ln -s libmali.so.1.9.0 "$out/lib/libmali.so.1"
    ln -s libmali.so.1 "$out/lib/libmali.so"
    ln -s libmali-hook.so.1.9.0 "$out/lib/libmali-hook.so.1"
    ln -s libmali-hook.so.1 "$out/lib/libmali-hook.so"
    ln -s libMaliOpenCL.so.1 "$out/lib/libMaliOpenCL.so"

    install -Dm644 extracted/etc/OpenCL/vendors/mali.icd \
      "$out/etc/OpenCL/vendors/mali.icd"
    install -Dm644 extracted/lib/firmware/mali_csffw.bin \
      "$out/lib/firmware/mali_csffw.bin"

    runHook postInstall
  '';

  meta = {
    description = "Rockchip Mali-G610 g24p0 OpenCL runtime for the RK3588 BSP kernel";
    homepage = "https://github.com/tsukumijima/libmali-rockchip";
    license = lib.licenses.unfreeRedistributable;
    platforms = [ "aarch64-linux" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
})
