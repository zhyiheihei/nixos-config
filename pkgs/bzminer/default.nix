# 闭源 GPU 矿工发行包（bzminer v100.60）。它带自检，会拒绝在不认识的环境里运行，
# 因此不改写 ELF，只在容器 rootfs 里以原始形态安装，运行时由 CDI 注入驱动库。
{
  lib,
  stdenv,
  fetchurl,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "bzminer";
  version = "100.60";

  src = fetchurl {
    url = "https://github.com/bzminer/bzminer/releases/download/v${finalAttrs.version}/bzminer_v${finalAttrs.version}_linux.tar.gz";
    hash = "sha256-HXNuCBiai7Cl6+Gx4bUVCbhq9K7qITN7j3mZJNRlM8U=";
  };

  sourceRoot = "bzminer_v${finalAttrs.version}_linux";

  dontPatchELF = true;
  dontStrip = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 bzminer $out/bin/bzminer
    runHook postInstall
  '';

  meta = {
    description = "Closed-source multi-algorithm GPU miner";
    homepage = "https://github.com/bzminer/bzminer";
    license = lib.licenses.unfree;
    mainProgram = "bzminer";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
})
