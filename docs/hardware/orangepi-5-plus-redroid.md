# Orange Pi 5 Plus reDroid with Mali GPU acceleration

The Orange Pi 5 Plus configuration uses the RK3588 vendor GPU stack:

- Armbian RK3588 vendor Linux 6.1 packaged by `gnull/nixos-rk3588`;
- the Mali CSF/Bifrost kernel driver and `/dev/mali0`;
- `CNflysky/redroid-rk3588:lineage-20`;
- persistent Android data in
  `/nix/persistent/var/lib/redroid-rk3588-lineage20`.

Only the kernel derivation is reused from `gnull/nixos-rk3588`. This repository
continues to own the Orange Pi 5 Plus U-Boot, extlinux configuration, disk
image, device configuration, persistence layout, and deployment metadata.

The previous Linux 6.18 Panthor experiment could initialize the host render
node, but the stock reDroid gralloc could not create a GBM device from it.
`vendor.gralloc` and SurfaceFlinger consequently restarted indefinitely.
Software rendering proved that the Android framework itself was healthy, but
it is not retained as a second production route.

## Build

Evaluate the configuration on an x86_64-linux or aarch64-linux Nix builder
before starting the long kernel build:

```bash
nix eval \
  .#nixosConfigurations.opi5p.config.system.build.sdImage.drvPath \
  --show-trace
```

Build the SD image:

```bash
nix build \
  .#nixosConfigurations.opi5p.config.system.build.sdImage \
  --out-link result-opi5p \
  --print-build-logs \
  --option max-jobs 4
```

The container image is pulled at runtime and is not embedded into the NixOS
SD image.

## Host validation

After booting the vendor kernel:

```bash
uname -a
test -c /dev/mali0
zgrep -E 'CONFIG_(MALI_BIFROST|MALI_CSF_SUPPORT|ANDROID_BINDERFS|PSI)=' \
  /proc/config.gz
ls -l /dev/dma_heap
dmesg | grep -iE 'mali|bifrost|csf|firmware|iommu'
```

Expected kernel features include:

- `CONFIG_MALI_BIFROST=y`;
- `CONFIG_MALI_CSF_SUPPORT=y`;
- `CONFIG_ANDROID_BINDERFS=y`;
- `CONFIG_PSI=y`;
- system DMA-BUF heaps.

The service deliberately refuses to start without `/dev/mali0`, so a missing
GPU driver cannot silently turn into software rendering.

## Android validation

```bash
systemctl status podman-redroid
podman logs redroid
podman exec redroid getprop sys.boot_completed
podman exec redroid getprop init.svc.surfaceflinger
podman exec redroid dumpsys SurfaceFlinger |
  grep -iE 'GLES|EGL|Mali|Rockchip|SwiftShader|llvmpipe'
```

`sys.boot_completed` should be `1`, SurfaceFlinger should remain `running`, and
the renderer must identify the Mali/Rockchip GPU rather than SwiftShader or
llvmpipe.

ADB remains bound only to the trusted LAN address:

```bash
adb connect 192.168.0.62:5555
```

## Rollback

Kernel deployment is a boot-critical change. Keep the current working
generation in extlinux until the vendor generation has passed:

1. cold boot;
2. both Ethernet ports;
3. Intel AX200 Wi-Fi and Bluetooth;
4. `/nix` early mount;
5. Mali GPU initialization;
6. reDroid boot and sustained GPU load.

If the new generation does not boot, select the previous generation from the
extlinux menu over serial console. Do not garbage-collect the old generation
before completing these checks.
