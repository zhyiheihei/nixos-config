# venus 冻结内核（设备原版 7.2.6 工件）缺的模块。
#
# 设备跑的是 pkgs/venus-kernel 里那份冻结工件，config 里
#   # CONFIG_ZRAM is not set
#   # CONFIG_DUMMY is not set
# 所以 zramSwap 会 modprobe 失败、netns 实例的 `ip link add type dummy` 直接
# "Operation not supported"。重建整套内核会把 ath11k 搞挂（MHI 固件崩溃，见
# venus-mainline docs/hardware-status.md 的 P1），因此只从同版本源码单独编译这几个模块。
#
# 不走 boot.extraModulePackages：nixpkgs 的 modules 聚合脚本依赖
# `modules.cer`（冻结工件里没有 .ko.cer，depmod 不会生成），会直接 cp 失败。
# 改为由 venus 板级模块在开机时 insmod（见 venus.extraKernelModules）。
#
# 模块与冻结内核同版本（vermagic 7.2.6 SMP preempt mod_unload aarch64），
# 实测 insmod 无符号冲突（dummy / zsmalloc / zram）。nft_masq、nft_redir
# 依赖的 nf_nat_redirect_* 在冻结内核里根本没编，带上也加载不了，故不含。
{ runCommand }:
runCommand "venus-extra-modules-7.2.6" { } ''
  mkdir -p $out/modules
  install -m644 ${./dummy.ko} $out/modules/dummy.ko
  install -m644 ${./zsmalloc.ko} $out/modules/zsmalloc.ko
  install -m644 ${./zram.ko} $out/modules/zram.ko
''
