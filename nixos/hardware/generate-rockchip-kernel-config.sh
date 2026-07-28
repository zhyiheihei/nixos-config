#!/usr/bin/env bash
set -euo pipefail

if (( $# != 3 )); then
	echo "usage: $0 KERNEL_SOURCE BOARD OUTPUT" >&2
	echo "BOARD: nanopi-r5c | orangepi-5-plus" >&2
	exit 2
fi

kernel_source=$1
board=$2
output=$3
config_tool="$kernel_source/scripts/config"
build_directory=$(mktemp -d)
trap 'rm -rf "$build_directory"' EXIT

make -C "$kernel_source" O="$build_directory" ARCH=arm64 defconfig

enable() {
	for symbol in "$@"; do
		"$config_tool" --file "$build_directory/.config" --enable "$symbol"
	done
}

module() {
	for symbol in "$@"; do
		"$config_tool" --file "$build_directory/.config" --module "$symbol"
	done
}

disable() {
	for symbol in "$@"; do
		"$config_tool" --file "$build_directory/.config" --disable "$symbol"
	done
}

# Boot, persistent storage and the Rockchip platform.
enable \
	ARCH_ROCKCHIP \
	BLK_DEV_INITRD \
	DEVTMPFS \
	DEVTMPFS_MOUNT \
	TMPFS \
	EXT4_FS \
	BTRFS_FS \
	VFAT_FS \
	NLS_CODEPAGE_437 \
	NLS_ISO8859_1 \
	MMC \
	MMC_SDHCI \
	MMC_SDHCI_PLTFM \
	MMC_SDHCI_OF_DWCMSHC \
	MMC_DW \
	MMC_DW_PLTFM \
	MMC_DW_ROCKCHIP \
	ROCKCHIP_IOMMU \
	ROCKCHIP_THERMAL \
	ROCKCHIP_GRF \
	ROCKCHIP_IODOMAIN \
	ROCKCHIP_PM_DOMAINS \
	PWM \
	PWM_ROCKCHIP \
	PCI \
	PCIEPORTBUS \
	PCIE_ROCKCHIP \
	PCIE_ROCKCHIP_HOST \
	PCIE_ROCKCHIP_DW \
	PCIE_ROCKCHIP_DW_HOST \
	NVME_CORE \
	BLK_DEV_NVME \
	USB \
	USB_XHCI_HCD \
	USB_XHCI_PLATFORM \
	USB_DWC3 \
	USB_DWC3_OF_SIMPLE

# arm64 defconfig targets most supported SoC families. These systems are
# Rockchip-only, so discard the unrelated platform trees before olddefconfig
# pulls in their clocks, pinctrl, PHY, media and display drivers.
disable \
	ACPI \
	ARCH_ACTIONS \
	ARCH_AIROHA \
	ARCH_ALPINE \
	ARCH_APPLE \
	ARCH_BCM \
	ARCH_BCMBCA \
	ARCH_BERLIN \
	ARCH_BITMAIN \
	ARCH_BRCMSTB \
	ARCH_EXYNOS \
	ARCH_HISI \
	ARCH_K3 \
	ARCH_KEEMBAY \
	ARCH_LAYERSCAPE \
	ARCH_LG1K \
	ARCH_MEDIATEK \
	ARCH_MESON \
	ARCH_MVEBU \
	ARCH_MXC \
	ARCH_NPCM \
	ARCH_QCOM \
	ARCH_REALTEK \
	ARCH_RENESAS \
	ARCH_S32 \
	ARCH_SEATTLE \
	ARCH_SOPHGO \
	ARCH_SPRD \
	ARCH_STM32 \
	ARCH_SUNXI \
	ARCH_SYNQUACER \
	ARCH_TEGRA \
	ARCH_THUNDER \
	ARCH_THUNDER2 \
	ARCH_UNIPHIER \
	ARCH_VEXPRESS \
	ARCH_VISCONTI \
	ARCH_XGENE \
	ARCH_ZYNQMP

# Ethernet and container/router networking shared by both boards.
enable \
	NET \
	INET \
	IPV6 \
	NETDEVICES \
	ETHERNET \
	STMMAC_ETH \
	STMMAC_PLATFORM \
	DWMAC_ROCKCHIP \
	MOTORCOMM_PHY \
	REALTEK_PHY \
	NETWORK_SECMARK \
	NETFILTER \
	NETFILTER_ADVANCED \
	NF_CONNTRACK \
	NF_NAT \
	NF_TABLES \
	NF_TABLES_INET \
	NF_TABLES_NETDEV \
	NF_TABLES_IPV4 \
	NF_TABLES_IPV6 \
	NFT_CT \
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
	IP_ADVANCED_ROUTER \
	IP_MULTIPLE_TABLES \
	IP_ROUTE_MULTIPATH \
	IPV6_MULTIPLE_TABLES \
	NET_SCHED \
	NET_CLS \
	NET_CLS_BPF \
	NET_ACT_BPF \
	NET_SCH_FQ_CODEL \
	NET_SCH_CAKE \
	BRIDGE \
	BRIDGE_IGMP_SNOOPING \
	BRIDGE_VLAN_FILTERING \
	VLAN_8021Q \
	CGROUPS \
	CGROUP_BPF \
	NAMESPACES \
	USER_NS \
	SECCOMP \
	SECCOMP_FILTER \
	OVERLAY_FS

module \
	WIREGUARD \
	IFB \
	TUN \
	VETH \
	MACVLAN \
	IPVLAN \
	VXLAN \
	GENEVE

# Remove large classes of hardware and filesystems that neither fixed-purpose
# board uses. Keep V4L2 core support for future RK3588 video acceleration, but
# drop USB webcams, analog TV and DVB receiver drivers.
disable \
	XEN \
	FIREWIRE \
	USB_GSPCA \
	MEDIA_USB_SUPPORT \
	MEDIA_PCI_SUPPORT \
	MEDIA_RADIO_SUPPORT \
	MEDIA_DIGITAL_TV_SUPPORT \
	MEDIA_SDR_SUPPORT \
	DVB_CORE \
	XFS_FS \
	GFS2_FS \
	OCFS2_FS \
	NILFS2_FS \
	BFS_FS \
	BEFS_FS \
	AFS_FS \
	9P_FS \
	CEPH_FS \
	CODA_FS \
	ORANGEFS_FS \
	ADFS_FS \
	AFFS_FS \
	HFS_FS \
	HFSPLUS_FS \
	JFS_FS \
	MINIX_FS \
	UFS_FS

case "$board" in
	nanopi-r5c)
		enable \
			PPP \
			PPP_FILTER \
			PPPOE \
			PPP_ASYNC \
			PPP_SYNC_TTY \
			BT \
			BT_BREDR \
			BT_LE
		enable WLAN
		module \
			BT_HCIBTUSB \
			CFG80211 \
			MAC80211 \
			MT76_CORE \
			MT76_CONNAC_LIB \
			MT792x_LIB \
			MT7921_COMMON \
			MT7921E
		# The installed card is MT7921. Disable unrelated MediaTek and all
		# Realtek WLAN generations while retaining the wired Realtek PHY.
		disable \
			MT7601U \
			MT76x0U \
			MT76x0E \
			MT76x2E \
			MT76x2U \
			MT7603E \
			MT7615E \
			MT7663U \
			MT7663S \
			MT7915E \
			MT7921U \
			MT7921S \
			MT7925E \
			MT7925U \
			MT7996E \
			WLAN_VENDOR_REALTEK
		;;
	orangepi-5-plus)
		enable \
			PSI \
			IKCONFIG \
			IKCONFIG_PROC \
			DMA_SHARED_BUFFER \
			DMABUF_HEAPS \
			DMABUF_HEAPS_SYSTEM \
			ANDROID_BINDER_IPC \
			ANDROID_BINDERFS \
			DRM \
			DRM_ROCKCHIP \
			HWMON \
			SENSORS_PWM_FAN \
			THERMAL \
			THERMAL_OF
		"$config_tool" \
			--file "$build_directory/.config" \
			--set-str ANDROID_BINDER_DEVICES \
			"binder,hwbinder,vndbinder"
		enable WLAN
		module \
			CFG80211 \
			MAC80211 \
			DRM_PANTHOR \
			MT76_CORE \
			MT76_CONNAC_LIB \
			MT792x_LIB \
			MT7921_COMMON \
			MT7921E \
			IWLWIFI \
			IWLMVM \
			RTW89 \
			RTW89_CORE \
			RTW89_PCI \
			RTW89_8852B \
			RTW89_8852BE
		# Retain only the three PCIe WLAN families available for this board:
		# MT7921, Intel 7265 (iwlwifi), and RTL8852BE.
		disable \
			MT7601U \
			MT76x0U \
			MT76x0E \
			MT76x2E \
			MT76x2U \
			MT7603E \
			MT7615E \
			MT7663U \
			MT7663S \
			MT7915E \
			MT7921U \
			MT7921S \
			MT7925E \
			MT7925U \
			MT7996E \
			RTL_CARDS \
			RTL8XXXU \
			RTW88
		;;
	*)
		echo "unsupported board: $board" >&2
		exit 2
		;;
esac

make -C "$kernel_source" \
	O="$build_directory" \
	ARCH=arm64 \
	olddefconfig

install -m 0644 "$build_directory/.config" "$output"
