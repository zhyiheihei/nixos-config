# Orange Pi 5 Plus reDroid with Mali GPU acceleration

## Validated production state

The configuration was validated on the physical `opi5p` host on 2026-07-30.
The following items work together:

- the vendor SPI bootloader and extlinux;
- the Armbian/Rockchip Linux 6.1.115 vendor kernel;
- NVMe-only boot with tmpfs `/` and persistent Btrfs `/nix`;
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

## Vendor bootloader in SPI

The vendor kernel must not run below Nixpkgs' mainline RK3588 U-Boot/ATF. That
combination was tested and failed with clock errors, PCIe resource failures,
RCU stalls, and an asynchronous SError kernel panic.

Use Armbian's `orangepi5-plus` `vendor` bootloader instead. It is built from
the Radxa RK3588 U-Boot tree with Armbian's board patches and produces the
complete 16 MiB `rkspi_loader.img` intended for SPI NOR. Do not substitute
Nixpkgs' `u-boot-rockchip-spi.bin`, despite its matching board name.

The NixOS image intentionally leaves the first 32 MiB free and does not embed
`idbloader.img` or `u-boot.itb`. Boot ROM therefore starts the Armbian loader
from SPI, which can load extlinux directly from the NVMe.

Before writing SPI, copy a full `/dev/mtd0` backup off the board and verify its
hash. Write only the complete `rkspi_loader.img`; keep a serial console and
MaskROM recovery available until a cold boot has succeeded.

An existing card that contains a previous mainline U-Boot must be rewritten
with the complete new image. `colmena apply` only changes the NixOS system
profile and boot files; it cannot replace or erase raw U-Boot sectors.

The previous Linux 6.18 Panthor experiment could initialize the host render
node, but the stock reDroid gralloc could not create a GBM device from it.
`vendor.gralloc` and SurfaceFlinger consequently restarted indefinitely.
Software rendering proved that the Android framework itself was healthy, but
it is not retained as a second production route.

## Disk and boot layout

The installed system follows the repository's physical-client persistence
model and lives entirely on the NVMe:

| NVMe region | Format | Mount point | Purpose |
| --- | --- | --- | --- |
| first 32 MiB | unused | - | Keep bootloader payloads in SPI, not on the NVMe |
| partition 1, `NVME_BOOT` | FAT, 256 MiB | `/boot` | extlinux, kernel, initrd and the filtered board DTB |
| partition 2, `NIXOS_NIX` | Btrfs | `/nix` | Nix store, system profile and `/nix/persistent` |
| runtime root | tmpfs | `/` | Ephemeral operating-system root |

The generated image is converted to GPT after Nixpkgs creates it because the
vendor boot chain expects a valid GPT. Partition 1 is the boot partition.
eMMC is neither mounted nor required after SPI and NVMe cold-boot validation.

This layout was cold-boot tested with the eMMC module physically removed. The
SPI loader found `/extlinux/extlinux.conf` on `NVME_BOOT`; Linux then mounted
both NVMe partitions, reached the current system closure, and started reDroid.

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

## Migrating from eMMC to NVMe-only boot

This is the validated migration procedure. Keep UART connected at 1500000
baud throughout the SPI change and first cold boot.

### 1. Build the matching Armbian vendor loader

Use the Armbian build framework on Ubuntu. The `vendor` branch matters: the
NixOS kernel and DTB come from the same Rockchip vendor stack.

```bash
cd ~/armbian-build

./compile.sh uboot \
  BOARD=orangepi5-plus \
  BRANCH=vendor \
  RELEASE=bookworm \
  BUILD_DESKTOP=no \
  KERNEL_CONFIGURE=no
```

The expected package name starts with
`linux-u-boot-orangepi5-plus-vendor_`. Extract and identify the complete SPI
image:

```bash
deb=$(find output/debs -maxdepth 1 \
  -name 'linux-u-boot-orangepi5-plus-vendor_*.deb' |
  sort | tail -1)

workdir=$(mktemp -d)
dpkg-deb -x "$deb" "$workdir"

loader="$workdir/usr/lib/linux-u-boot-vendor-orangepi5-plus/rkspi_loader.img"
stat -c '%s bytes' "$loader"
sha256sum "$loader"
```

`rkspi_loader.img` must be exactly 16777216 bytes. The image validated on
2026-07-30 was built by Armbian as
`2017.09_armbian-2017.09-S39cd-Pdcf8-Hbe55-V5abd-B5da4-R448a`; its SHA-256
was:

```text
97b52ca002b617a3cd1574953323442a645e3e7c0ec1e88e8bc3c31d65c2589b
```

The apparent `2017.09` version does not make it interchangeable with an
OpenWrt/EasePi loader. Armbian applies its RK3588 and board patches and bundles
the matching DDR firmware and ATF. Always verify a newly built artifact rather
than requiring the historical hash above.

### 2. Prepare the NVMe

The target must contain:

- GPT partition 1: FAT, label `NVME_BOOT`, mounted at `/boot`;
- GPT partition 2: Btrfs, label `NIXOS_NIX`, mounted at `/nix`.

Deploy the configuration after migrating the Nix store and persistent
subvolume:

```bash
nix run .#colmena -- apply --on opi5p
```

Confirm that `/boot` is already the NVMe partition before rebuilding extlinux:

```bash
findmnt /boot
findmnt /nix
lsblk -o NAME,PATH,SIZE,FSTYPE,LABEL,MOUNTPOINTS
```

If a previous safety test renamed the boot directory to
`extlinux.nvme-disabled`, restore it once:

```bash
test ! -e /boot/extlinux
mv /boot/extlinux.nvme-disabled /boot/extlinux
/run/current-system/bin/switch-to-configuration boot
sync
```

The default extlinux entry must name the current system closure, and every
referenced file must exist:

```bash
readlink -f /run/current-system
sed -n '1,30p' /boot/extlinux/extlinux.conf

awk '/^[[:space:]]+(LINUX|INITRD|FDT)[[:space:]]/ { print $2 }' \
  /boot/extlinux/extlinux.conf |
sort -u |
while read -r relative; do
  test -f "$(realpath -m "/boot/extlinux/$relative")"
done
```

### 3. Back up and write SPI NOR

Save the entire 16 MiB SPI contents on another machine. A backup left only on
the board is not a recovery copy.

```bash
dd if=/dev/mtd0 of=/tmp/opi5p-spi-backup.bin bs=1M count=16
sha256sum /tmp/opi5p-spi-backup.bin
```

Copy that file off the board before continuing. Then copy the new
`rkspi_loader.img` to the board, verify its size and hash, and write it:

```bash
test "$(stat -c %s /tmp/opi5p-rkspi-loader.img)" = 16777216
sha256sum /tmp/opi5p-rkspi-loader.img

dd \
  if=/tmp/opi5p-rkspi-loader.img \
  of=/dev/mtdblock0 \
  bs=64K \
  conv=fsync,notrunc \
  status=progress
sync
```

Writing takes several minutes. Do not interrupt it. Read the complete SPI back
and require an exact match before rebooting:

```bash
sha256sum /tmp/opi5p-rkspi-loader.img /dev/mtd0
```

`flashcp -v rkspi_loader.img /dev/mtd0` is also valid when `mtd-utils` is
already installed. Do not trigger a full native toolchain build on the board
solely to obtain it.

### 4. Prove that eMMC is not required

This is a physical test, not an inference from mount output:

1. run `systemctl poweroff` and wait for `reboot: Power down` on UART;
2. disconnect power;
3. physically remove the eMMC module;
4. leave only SPI NOR and NVMe installed;
5. reconnect power and capture the complete UART log.

The successful chain contains:

```text
U-Boot SPL ... armbian ...
Model: Orange Pi 5 Plus
Device 0: ... NVMe ...
Scanning nvme 0:1...
Found /extlinux/extlinux.conf
Starting kernel ...
Welcome to NixOS
```

After SSH becomes available, require all of the following:

```bash
test ! -e /dev/mmcblk0
findmnt /boot
findmnt /nix
readlink -f /run/current-system
nvme list
systemctl is-active podman-redroid.service
```

Expected storage sources are `/dev/nvme0n1p1` for `/boot` and
`/dev/nvme0n1p2` for `/nix`. No `mmcblk` device should exist.

If U-Boot prints `Invalid FAT entry` but still reads the files, repair the boot
filesystem immediately:

```bash
sync
umount /boot
fsck.fat -a -v /dev/nvme0n1p1
mount /boot
test -f /boot/extlinux/extlinux.conf
```

The vendor kernel may print `dw-pcie ... invalid resource` for several
duplicated platform nodes before the working PCI domain probes. Judge the
result by the later `nvme nvme0: pci function ...`, successful NVMe mounts,
and the absence of I/O errors—not by those early lines alone.

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

## Memory & swap (2026-08/09 rework)

16 GiB RAM running 15+ heavyweight services (Frigate, Immich, HA, Postgres,
bitmagnet, NCPS...) exceeds physical memory under load. Two hard lessons:

- **zram is disabled on this host.** With memory nearly full, zram's zstd
  compress/decompress pushed kswapd0 to a full core (98.5% CPU) and the box
  entered a swap-storm death spiral (load 181, all tasks in D state, SSH
  dropping). Disk swap (NVMe GT50, ~1.8 GB/s) keeps the system slow but
  alive; at true exhaustion the OOM killer frees memory deterministically.
  The same fix was applied to dragon-q8b after its Resilio/bitmagnet
  migration. zram remains appropriate on ml-builder (memory-rich, compile
  bursts) — this is per-host tuning, not a fleet-wide policy.
- **The swapfile lives in a dedicated `/nix/swap` subvolume.** btrfs refuses
  to snapshot a subvolume containing an active swapfile (EBUSY "Text file
  busy"), and this host's `/nix` has no subvolume layout (persistent is a
  plain directory, so `snapshot -r /nix` would include everything and
  backup-nix-persistent would fail nightly). Snapshots do not recurse into
  nested subvolumes, so `/nix/swap` solves EBUSY and backup redundancy at
  once; the swapfile needs no resticIgnored entry.

First-boot bootstrap: `swapDevices` only activates existing files, and the
dd image ships no 4G swapfile, so `opi5p-swapfile-bootstrap` creates the
subvolume + swapfile on demand before `swap.target`. Its
`DefaultDependencies` must stay off — the implicit `After=basic.target`
would form a swap.target → unit → basic.target → sysinit.target ordering
cycle and systemd would drop swap.target entirely (observed on first NVMe
boot: no swap at all).

## Rollback

Keep the off-board 16 MiB SPI backup until repeated cold boots, networking,
GPU, fan and sustained reDroid I/O have passed. If the new loader does not
start, enter RK3588 MaskROM mode from a recovery host, restore the saved SPI
image, and boot the previous eMMC or recovery card. An extlinux generation
cannot roll back raw SPI contents.

If U-Boot starts but the NVMe system does not, use a temporary recovery card
or reinstall eMMC, then inspect `NVME_BOOT`, its FAT filesystem and extlinux
references. Do not erase the recovery media or garbage-collect the previous
system closure before the NVMe-only cold boot is proven.

When a configuration-only deployment fails after U-Boot has loaded extlinux,
select the previous NixOS generation from the serial console instead. The boot
partition retains two generations. This does not help if raw card sectors or
SPI contents were changed.
