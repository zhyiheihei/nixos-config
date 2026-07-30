# Orange Pi 5 Plus reDroid with Mali GPU acceleration

## Validated production state

The configuration was validated on the physical `opi5p` host on 2026-07-30.
The following items work together:

- the vendor SPI bootloader and extlinux;
- the Armbian/Rockchip Linux 6.1.115 vendor kernel;
- SD-card boot with tmpfs `/` and persistent Btrfs `/nix`;
- both onboard RTL8125 Ethernet ports with stable names;
- the Mali CSF/Bifrost driver and `/dev/mali0`;
- the RK3588 PWM fan with a repository-defined temperature curve;
- the LineageOS 20 reDroid container with GPU acceleration;
- a 1280x720 landscape Android display with the navigation buttons on the
  right-hand edge.

The implementation is split between:

- `nixos/hardware/orangepi-5-plus/default.nix` for the kernel, DTB, image,
  storage, fan, clock and boot contract;
- `hosts/opi5p/configuration.nix` for physical network identity and reDroid;
- `hosts/opi5p/hardware-configuration.nix` for importing the board module.

The Orange Pi 5 Plus configuration uses the RK3588 vendor GPU stack:

- Armbian RK3588 vendor Linux 6.1 packaged by `gnull/nixos-rk3588`;
- the Mali CSF/Bifrost kernel driver and `/dev/mali0`;
- `CNflysky/redroid-rk3588:lineage-20`;
- persistent Android data in
  `/nix/persistent/var/lib/redroid-rk3588-lineage20`.

The kernel derivation and boot-chain contract follow `gnull/nixos-rk3588`.
This repository continues to own the extlinux configuration, disk partitions,
persistence layout, networking, and deployment metadata.

The kernel is cross-compiled on the x86_64 builder with
`pkgsCross.aarch64-multiplatform`. The ARM compiler, assembler and linker do
not run through qemu-user.

## Existing vendor bootloader in SPI

The vendor kernel must not run below Nixpkgs' mainline RK3588 U-Boot/ATF. That
combination was tested and failed with clock errors, PCIe resource failures,
RCU stalls, and an asynchronous SError kernel panic.

This board already has its vendor bootloader in SPI NOR from the earlier
eMMC-first setup. Do not reinstall or erase SPI as part of this migration.

The NixOS image intentionally leaves the first 32 MiB free and does not embed
`idbloader.img` or `u-boot.itb`. Without the mainline SPL in the SD-card raw
area taking precedence, Boot ROM can use the existing vendor bootloader from
SPI. That bootloader retains the established eMMC/SD boot priority and loads
extlinux from the selected device.

An existing card that contains the previous mainline U-Boot must be rewritten
with the complete new image. `colmena apply` only changes the NixOS system
profile and boot files; it cannot replace or erase raw U-Boot sectors.

The previous Linux 6.18 Panthor experiment could initialize the host render
node, but the stock reDroid gralloc could not create a GBM device from it.
`vendor.gralloc` and SurfaceFlinger consequently restarted indefinitely.
Software rendering proved that the Android framework itself was healthy, but
it is not retained as a second production route.

## Disk and boot layout

The generated image deliberately follows the repository's physical-client
persistence model:

| Region | Format | Mount point | Purpose |
| --- | --- | --- | --- |
| first 32 MiB | unused | - | Preserve the vendor SPI boot contract; do not embed mainline U-Boot |
| partition 1 | FAT, 256 MiB | `/boot` | extlinux, kernel, initrd and the filtered board DTB |
| partition 2 | Btrfs | `/nix` | Nix store, system profile and `/nix/persistent` |
| runtime root | tmpfs | `/` | Ephemeral operating-system root |

The image is converted to GPT after Nixpkgs creates it because the board's
vendor U-Boot 2017.09 incorrectly selects its EFI partition parser for the
generic MBR image and does not fall back to DOS partitions. Partition 1 is the
boot partition.

On first boot, `opi5p-grow-nix.service` expands partition 2 and the mounted
Btrfs filesystem to fill the card. `/nix` is marked `neededForBoot`; removing
that setting makes cold boot unable to locate the system closure.

Check the result with:

```bash
for target in / /boot /nix; do
  findmnt --target "$target"
done
systemctl status opi5p-grow-nix
lsblk -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINTS
```

## Stable onboard Ethernet names

Both onboard ports use `r8169`, so kernel probe order must not be used as
physical identity. The host assigns names from permanent MAC addresses:

| Permanent MAC | Stable name | Configuration |
| --- | --- | --- |
| `c0:74:2b:ff:5c:fd` | `lan0` | primary address and default route |
| `c0:74:2b:ff:5c:fc` | `lan1` | rescue address `192.168.0.63/24`, no default route |

Both the `.link` and `.network` units match the permanent MAC address. This
keeps the physical port assignment stable even if PCIe enumeration changes.

```bash
networkctl status lan0 lan1
ip -br address show dev lan0
ip -br address show dev lan1
```

## Vendor DTB and PWM fan

The board must boot the unmerged vendor
`rockchip/rk3588-orangepi-5-plus.dtb`. Keep
`hardware.deviceTree.overlays = [ ];`.

Do not apply a mainline-style NixOS device-tree overlay to this vendor tree.
The attempted overlay duplicated reserved-memory and RK3588 platform nodes,
which produced PCIe, GPU and NPU resource conflicts immediately after
`Starting kernel ...`.

Fan customization instead happens before the kernel builds the DTB. The
kernel derivation applies
`nixos/hardware/orangepi-5-plus/vendor-fan-curve.patch` directly to the
board's vendor DTS. The validated curve is:

| SoC temperature | PWM value |
| ---: | ---: |
| below 42°C | 0 |
| 42°C | 90 |
| 48°C | 140 |
| 54°C | 180 |
| 60°C | 220 |
| 66°C | 255 |

`cooling-levels` contains six values, while `rockchip,temp-trips` contains
five threshold/state pairs. State 1 selects the second cooling value and state
5 selects the sixth; do not create a state outside that range.

Runtime validation:

```bash
cat /sys/class/thermal/thermal_zone0/temp
cat /sys/class/hwmon/hwmon*/name

for hwmon in /sys/class/hwmon/hwmon*; do
  if test "$(cat "$hwmon/name" 2>/dev/null)" = pwmfan; then
    cat "$hwmon/pwm1"
    cat "$hwmon/pwm1_enable"
  fi
done
```

At approximately 44°C, the validated machine reported `pwm1=90` and
`pwm1_enable=1`. The vendor driver exposes the fan through hwmon and does not
create a standard thermal `cooling_device`.

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

After the machine is installed and reachable, normal configuration changes do
not require rebuilding or rewriting an SD image:

```bash
nix run .#colmena -- apply --on opi5p
```

Rebuild the complete image only for initial installation, recovery, or raw
partition/boot-chain changes.

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

## Landscape display and right-side navigation

Android chooses navigation-bar placement from the display's natural rotation,
not only from its final width and height. Defining reDroid directly as
1280x720 makes landscape `ROTATION_0`, so SystemUI keeps the three-button
navigation bar at the bottom.

The production configuration therefore:

1. creates a portrait-native virtual panel with
   `androidboot.redroid_width=720` and
   `androidboot.redroid_height=1280`;
2. waits for `sys.boot_completed=1`;
3. runs `wm size reset`;
4. locks the display to rotation 1.

The resulting Android display remains 1280x720, while SystemUI uses its
landscape right-side navigation layout. The persistent setup is performed by
`redroid-landscape-navigation.service`.

```bash
systemctl status redroid-landscape-navigation
podman exec redroid wm size
podman exec redroid settings get system user_rotation
podman exec redroid dumpsys window windows |
  grep -A35 'Window #.*NavigationBar0' |
  grep -E 'mAttrs=|Requested|mFullConfiguration|Frames:'
```

Expected values include:

```text
Physical size: 720x1280
user_rotation=1
mDisplayRotation=ROTATION_90
gr=RIGHT
frame=[1184,0][1280,720]
```

The exact `Physical size`/`Override size` wording can differ before the
container is recreated from the declarative configuration. The authoritative
checks are the final 1280x720 bounds, `ROTATION_90` and a right-edge navigation
frame.

## Rollback

The vendor boot chain must first be tested on a separate SD card. Keep the
current mainline recovery card unchanged until the vendor image has passed:

1. cold boot;
2. both Ethernet ports;
3. Intel AX200 Wi-Fi and Bluetooth;
4. `/nix` early mount;
5. Mali GPU initialization;
6. reDroid boot and sustained GPU load.

If the new image does not boot, power off and restore the mainline recovery
card. An extlinux generation alone cannot roll back raw bootloader changes.
Do not garbage-collect the old system closure before completing these checks.

When a configuration-only deployment fails after U-Boot has loaded extlinux,
select the previous NixOS generation from the serial console instead. The boot
partition retains two generations. This does not help if raw card sectors or
SPI contents were changed.
