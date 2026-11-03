# Kryptex KRig 矿工（闭源发行包）。CUDA 内核已随二进制分发，运行期只通过
# dlopen 取驱动的 libcuda.so.1，不需要 CUDA toolkit。
{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  openssl,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "krig-miner";
  version = "1.5.13";

  src = fetchurl {
    url = "https://github.com/kryptex/krig-miner/releases/download/v${finalAttrs.version}/krig-miner-${finalAttrs.version}-linux-x64.tar.gz";
    hash = "sha256-IaQbQ3HW95tYv4fPeWQbOy3ILrqy40gZM3lKsR28r5g=";
  };

  sourceRoot = ".";

  nativeBuildInputs = [ autoPatchelfHook ];

  buildInputs = [ stdenv.cc.cc.lib ];

  # libcuda.so.1 与 TLS 均由运行时 dlopen 获取，必须写进 RPATH；openssl 默认
  # 输出为 bin，库文件在 out
  appendRunpaths = [ "/run/opengl-driver/lib" ];
  runtimeDependencies = [ openssl.out ];

  installPhase = ''
    runHook preInstall
    install -Dm755 krig-miner $out/bin/krig-miner
    install -Dm755 libkrig_quantus_intel.so $out/bin/lib/libkrig_quantus_intel.so
    runHook postInstall
  '';

  meta = {
    description = "Pearl (PRL) and Quantus (QTC) GPU miner by Kryptex Pool";
    homepage = "https://github.com/kryptex/krig-miner";
    license = lib.licenses.unfree;
    mainProgram = "krig-miner";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
})
