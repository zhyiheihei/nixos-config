#!/usr/bin/env bash
set -euo pipefail

if (( $# != 2 )); then
	echo "usage: $0 KERNEL_SOURCE OUTPUT" >&2
	exit 2
fi

kernel_source=$1
output=$2
config_tool="$kernel_source/scripts/config"
build_directory=$(mktemp -d)
trap 'rm -rf "$build_directory"' EXIT

# The hardware and Android ABI baseline is the H618 Android defconfig shipped
# by the exact Orange Pi vendor-kernel commit used by default.nix.  Do not use
# the generic sun50iw9 or Linux/server defconfig here: both select unrelated
# driver generations and omit parts of the H618 Android media stack.
make -s -C "$kernel_source" \
	O="$build_directory" \
	ARCH=arm64 \
	sun50iw9p1smp_h618_android_defconfig

enable() {
	for symbol in "$@"; do
		"$config_tool" --file "$build_directory/.config" --enable "$symbol"
	done
}

disable() {
	for symbol in "$@"; do
		"$config_tool" --file "$build_directory/.config" --disable "$symbol"
	done
}

# NixOS early boot and the SD-image layout.  The official Android image uses
# ext4, while this repository persists /nix on Btrfs and boots with a tmpfs /.
enable \
	FHANDLE \
	SYSVIPC \
	AIO \
	BLK_DEV_INITRD \
	DEVTMPFS \
	DEVTMPFS_MOUNT \
	TMPFS \
	TMPFS_POSIX_ACL \
	TMPFS_XATTR \
	EXT4_FS \
	BTRFS_FS \
	BTRFS_FS_POSIX_ACL \
	FAT_FS \
	VFAT_FS \
	NLS_CODEPAGE_437 \
	NLS_ISO8859_1 \
	MMC \
	MMC_SUNXI \
	MODULES \
	MODULE_UNLOAD \
	IKCONFIG \
	IKCONFIG_PROC

# systemd, Podman and Android task profiles need the complete namespace and
# controller set.  The board-vendor defconfig is an Android *guest* kernel and
# deliberately disables several of these; opi03 is also the container host.
enable \
	PSI \
	CGROUPS \
	CGROUP_FREEZER \
	CGROUP_PIDS \
	CGROUP_DEVICE \
	CPUSETS \
	PROC_PID_CPUSET \
	CGROUP_CPUACCT \
	CGROUP_SCHED \
	FAIR_GROUP_SCHED \
	CFS_BANDWIDTH \
	RT_GROUP_SCHED \
	MEMCG \
	MEMCG_SWAP \
	MEMCG_SWAP_ENABLED \
	BLK_CGROUP \
	CGROUP_WRITEBACK \
	CGROUP_PERF \
	CGROUP_BPF \
	NAMESPACES \
	UTS_NS \
	IPC_NS \
	USER_NS \
	PID_NS \
	NET_NS \
	SECCOMP \
	SECCOMP_FILTER \
	BPF \
	BPF_SYSCALL \
	BPF_JIT \
	BPF_JIT_ALWAYS_ON \
	MEMFD_CREATE

# The repository firewall and Podman both use nftables.  Keep legacy xtables
# selected by the Android baseline as well, because Android 12 vendor services
# still invoke it.  BBR/FQ matches the repository-wide sysctl policy.
enable \
	NET \
	INET \
	IPV6 \
	NETDEVICES \
	ETHERNET \
	NETWORK_SECMARK \
	NETFILTER \
	NETFILTER_ADVANCED \
	NF_CONNTRACK \
	NF_NAT \
	NF_TABLES \
	NF_TABLES_SET \
	NF_TABLES_INET \
	NF_TABLES_NETDEV \
	NF_TABLES_IPV4 \
	NF_TABLES_IPV6 \
	NFT_CT \
	NFT_COUNTER \
	NFT_FLOW_OFFLOAD \
	NFT_LOG \
	NFT_LIMIT \
	NFT_MASQ \
	NFT_REDIR \
	NFT_NAT \
	NFT_TPROXY \
	NFT_SOCKET \
	NFT_FIB \
	NFT_FIB_INET \
	NFT_FIB_IPV4 \
	NFT_FIB_IPV6 \
	NFT_REJECT \
	NFT_REJECT_INET \
	NFT_REJECT_IPV4 \
	NFT_REJECT_IPV6 \
	NFT_COMPAT \
	NETFILTER_XTABLES \
	NETFILTER_XT_MATCH_ADDRTYPE \
	NETFILTER_XT_MATCH_COMMENT \
	NETFILTER_XT_MATCH_CONNTRACK \
	NETFILTER_XT_TARGET_MASQUERADE \
	BRIDGE \
	BRIDGE_NETFILTER \
	BRIDGE_IGMP_SNOOPING \
	BRIDGE_VLAN_FILTERING \
	VLAN_8021Q \
	NET_SCHED \
	NET_CLS \
	NET_CLS_BPF \
	NET_ACT_BPF \
	NET_SCH_FQ \
	TCP_CONG_ADVANCED \
	TCP_CONG_BBR \
	TUN \
	VETH \
	MACVLAN \
	IPVLAN \
	VXLAN \
	OVERLAY_FS

# The Orange Pi vendor branch only ships a generic H618 Android defconfig.
# Reapply the small, board-specific delta proven by the public Zero 3 p3
# Android 12 configuration.  The YT8531 needs its Motorcomm driver; the
# vendor DTS exposes two GPIO LEDs; the board patch turns the boot-stage red
# LED off after probe and makes the green runtime LED heartbeat.
# A 128 KiB printk ring also matches both Orange Pi's Linux image config and
# the p3 Android config, which is important while bringing up Mali/Cedar.
enable \
	MOTORCOMM_PHY \
	LEDS_CLASS \
	LEDS_GPIO \
	LEDS_TRIGGERS \
	LEDS_TRIGGER_HEARTBEAT

"$config_tool" \
	--file "$build_directory/.config" \
	--set-val LOG_BUF_SHIFT 17

# Reassert the matched H618 Android ABI.  Kbase is built as an external module
# from the same source, while ION/G2D/Cedar and Binder remain in the host
# kernel.  256 MiB CMA is required by simultaneous Mali and video surfaces.
enable \
	ANDROID \
	ANDROID_BINDER_IPC \
	ANDROID_BINDERFS \
	ASHMEM \
	ION \
	ION_SYSTEM_HEAP \
	ION_CMA_HEAP \
	CMA \
	CMA_SIZE_SEL_MBYTES \
	SUNXI_G2D \
	SUNXI_G2D_ROTATE \
	SUNXI_DI \
	SUNXI_DI_V3X

"$config_tool" \
	--file "$build_directory/.config" \
	--set-str ANDROID_BINDER_DEVICES \
	"binder,hwbinder,vndbinder"
"$config_tool" \
	--file "$build_directory/.config" \
	--set-val CMA_SIZE_MBYTES 256

# These are deliberate exceptions to Kconfig defaults and the board defconfig.
# H618 uses DI300 and the v4p1x/v4p5x MMC implementations.  The onboard
# AW859A/UWE5622 stack is deferred as one unit: Armbian's working Zero 3 case
# also requires matching firmware and a custom Bluetooth attach helper.  Do
# not compile only half of that stack into the GPU/VPU bring-up kernel.
# SUNXI_NAND is the out-of-tree modules/nand Longan driver: its Makefile
# requires LICHEE_KDIR, which no Nix sandbox provides, and the Zero 3 boots
# from microSD/eMMC over MMC, not from a raw NAND device.
disable \
	SUNXI_NAND \
	SUNXI_DI_V1XX \
	SUNXI_DI_V2X \
	MMC_SUNXI_V4P10X \
	SPARD_WLAN_SUPPORT \
	AW_WIFI_DEVICE_UWE5622 \
	WLAN_UWE5622 \
	TTY_OVERY_SDIO

make -s -C "$kernel_source" \
	O="$build_directory" \
	ARCH=arm64 \
	olddefconfig

require_line() {
	local expected=$1
	if ! grep -qxF "$expected" "$build_directory/.config"; then
		echo "generated kernel config is missing: $expected" >&2
		exit 1
	fi
}

require_disabled() {
	local symbol=$1
	if grep -qE "^CONFIG_${symbol}=[ym]$" "$build_directory/.config"; then
		echo "generated kernel config unexpectedly enables: CONFIG_${symbol}" >&2
		exit 1
	fi
}

# Fail while generating, not after a multi-hour cross build or on the board.
for expected in \
	'CONFIG_ARCH_SUN50IW9=y' \
	'CONFIG_SUNXI_GMAC=y' \
	'CONFIG_MOTORCOMM_PHY=y' \
	'CONFIG_SERIAL_SUNXI=y' \
	'CONFIG_SERIAL_SUNXI_CONSOLE=y' \
	'CONFIG_LOG_BUF_SHIFT=17' \
	'CONFIG_LEDS_GPIO=y' \
	'CONFIG_LEDS_TRIGGER_HEARTBEAT=y' \
	'CONFIG_MMC_SUNXI=y' \
	'CONFIG_MMC_SUNXI_V4P1X=y' \
	'CONFIG_MMC_SUNXI_V4P5X=y' \
	'# CONFIG_MMC_SUNXI_V4P10X is not set' \
	'CONFIG_BTRFS_FS=y' \
	'CONFIG_CGROUP_PIDS=y' \
	'CONFIG_CGROUP_DEVICE=y' \
	'CONFIG_PID_NS=y' \
	'CONFIG_USER_NS=y' \
	'CONFIG_NF_TABLES=y' \
	'CONFIG_NF_TABLES_SET=y' \
	'CONFIG_NFT_MASQ=y' \
	'CONFIG_NET_SCH_FQ=y' \
	'CONFIG_TCP_CONG_BBR=y' \
	'CONFIG_ANDROID_BINDER_IPC=y' \
	'CONFIG_ANDROID_BINDERFS=y' \
	'CONFIG_ANDROID_BINDER_DEVICES="binder,hwbinder,vndbinder"' \
	'CONFIG_DMA_SHARED_BUFFER=y' \
	'CONFIG_SYNC_FILE=y' \
	'CONFIG_ION=y' \
	'CONFIG_ION_CMA_HEAP=y' \
	'CONFIG_CMA_SIZE_MBYTES=256' \
	'CONFIG_VIDEO_ENCODER_DECODER_SUNXI=y' \
	'CONFIG_DISP2_SUNXI=y' \
	'CONFIG_SUNXI_G2D=y' \
	'CONFIG_SUNXI_DI_V3X=y'
do
	require_line "$expected"
done

require_disabled AW_WIFI_DEVICE_UWE5622
require_disabled SPARD_WLAN_SUPPORT
require_disabled WLAN_UWE5622
require_disabled TTY_OVERY_SDIO
require_disabled SUNXI_NAND
require_disabled SUNXI_RAWNAND

install -m 0644 "$build_directory/.config" "$output"
