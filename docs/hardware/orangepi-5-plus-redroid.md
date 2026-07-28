# Orange Pi 5 Plus mainline reDroid

The default Orange Pi 5 Plus configuration follows the upstream GPU stack:

- Linux 6.18 from Nixpkgs;
- the mainline Panthor kernel driver;
- the upstream reDroid arm64 image;
- `/dev/dri/renderD128` passed to the container;
- persistent Android data in `/nix/persistent/var/lib/redroid`.

The Armbian RK3588 vendor kernel and `CNflysky/redroid-rk3588` remain the
fallback. They are not part of the default build, so the normal NixOS image has
no build-time dependency on the Armbian build framework.

## Build

Evaluate the configuration before starting the long kernel build:

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
  --print-build-logs
```

The reDroid container image is pulled at runtime. It is not embedded into the
NixOS SD image.

## Host GPU validation

Before diagnosing Android, verify that the host initialized Panthor:

```bash
ls -l /dev/dri
dmesg | grep -iE 'panthor|mali|firmware|iommu'
cat /sys/kernel/debug/dri/0/name
```

The expected render node is `/dev/dri/renderD128`. The `podman-redroid` service
waits for this device and does not deliberately fall back to software
rendering.

The board's PWM fan is managed by the kernel thermal subsystem. The NixOS
device-tree overlay uses an intentionally cool-biased curve:

| Package temperature | PWM level |
| --- | --- |
| below 42 C | off |
| 42 C | 90 / 255 |
| 48 C | 140 / 255 |
| 55 C | 200 / 255 |
| 62 C | 255 / 255 |

Each trip has 3 C hysteresis to prevent rapid fan speed oscillation. Confirm
that the cooling device and thermal zone were registered:

```bash
grep . /sys/class/thermal/thermal_zone*/type
grep . /sys/class/thermal/cooling_device*/type
watch -n1 'cat /sys/class/thermal/thermal_zone*/temp'
```

Inspect the service and container:

```bash
systemctl status podman-redroid
journalctl -b -u podman-redroid
podman logs redroid
```

## Android GPU validation

Connect only from the trusted LAN. ADB is bound to the board's interconnect
address on TCP port 5555.

```bash
adb connect 192.168.0.62:5555
adb shell dumpsys SurfaceFlinger |
  grep -iE 'GLES|EGL|Mesa|Mali|Panfrost|SwiftShader'
```

A successful mainline result identifies `Mesa`, `Mali-G610`, and
`Panfrost`/`Panthor`. `SwiftShader` or `llvmpipe` means the container is using
software rendering.

Also check the kernel log during a sustained GPU workload:

```bash
dmesg --follow |
  grep -iE 'panthor|fault|timeout|hang|firmware|iommu'
```

## Vendor fallback gate

Do not switch kernels merely because the container fails to start. First
separate these failure classes:

1. no `/dev/dri/renderD128`: host kernel, device tree, or firmware problem;
2. render node exists but Android reports SwiftShader: container Mesa/gralloc
   problem;
3. Android identifies Mali-G610 but crashes or faults under load: Panthor,
   DMA-BUF, or IOMMU compatibility problem.

Use the Armbian vendor 6.1 + Mali CSF + `CNflysky/redroid-rk3588` fallback only
if the third class cannot be stabilized, or if the required application has a
measured regression that makes the mainline stack unsuitable. Preserve the
working mainline host as a separate boot generation while testing the fallback.
