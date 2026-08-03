{
  kernel,
  lib,
  nixpkgsPath,
  ...
}:
let
  crossPkgs = import nixpkgsPath {
    localSystem = "x86_64-linux";
    crossSystem = lib.systems.examples.aarch64-multiplatform;
    config = { };
    overlays = [ ];
  };
  kdir = "${kernel.dev}/lib/modules/${kernel.modDirVersion}/build";
in
crossPkgs.stdenv.mkDerivation {
  pname = "opi03-mali-kbase";
  version = "r20p0-01rel0-${kernel.modDirVersion}";
  src = kernel.vendorSource;

  sourceRoot = "source/modules/gpu/mali-bifrost/driver/drivers/gpu/arm/midgard";
  nativeBuildInputs = kernel.moduleBuildDependencies;
  requiredSystemFeatures = [ "aarch64-cross" ];

  # Kbase r20 is the exact kernel-side ABI paired with the Android 12 H618
  # libGLES_mali.so.  Do not replace it with Panfrost or a newer random Kbase
  # release: either change would break the tested vendor userspace contract.
  # MALI_DMA_FENCE is deliberately left at its Kconfig default (n): the
  # r20p0 dma_fence code uses the pre-5.5 `struct reservation_object` API,
  # while this vendor 5.4 branch renamed it to dma-resv.h, and Android 12's
  # gralloc/Codec2 fence path goes through SYNC_FILE instead.
  makeFlags = [
    "ARCH=arm64"
    "CROSS_COMPILE=${crossPkgs.stdenv.cc.targetPrefix}"
    "KDIR=${kdir}"
    "CONFIG_MALI_MIDGARD=m"
    "CONFIG_MALI_PLATFORM_NAME=sunxi"
    "CONFIG_MALI_DEVFREQ=y"
    "CONFIG_SYNC_FILE=y"
  ];

  installPhase = ''
    runHook preInstall
    # buildPhase already ran `make -C $KDIR M=$PWD modules`, which emits
    # mali_kbase.ko in the midgard source dir.  modules_install via the
    # kernel build tree is unreliable here (the mkmakefile build/Makefile
    # triggers an extra sub-make round that misinterprets ARCH), so install
    # the built module directly into the standard NixOS extra module slot.
    install -Dm0644 mali_kbase.ko \
      "$out/lib/modules/${kernel.modDirVersion}/extra/mali_kbase.ko"
    runHook postInstall
  '';

  dontStrip = true;
  meta = {
    description = "Allwinner H618 Mali-G31 Kbase module paired with the vendor Android 12 UMD";
    license = lib.licenses.gpl2Only;
    platforms = [ "aarch64-linux" ];
  };
}
