# HINLINK H28K（RK3528）NixOS 路由器适配

本文记录 `h28k` 主机的首启镜像、双网口路由和正式入网门禁。当前配置已经通过
`sdImage.drvPath` 求值，但尚未完成整镜像构建与真机串口验收；因此本文会明确区分
“已由源码确认”和“待上电确认”，不把可求值等同于可启动。

## 当前目标

| 项目 | 配置 |
| --- | --- |
| SoC | Rockchip RK3528 / 4 × Cortex-A53 / `aarch64-linux` |
| 主机身份 | `hosts/h28k/`，index `125`，首启期间 `manualDeploy = true` |
| LAN | `eth0`，静态 `192.168.30.1/24` |
| WAN | `eth1`，IPv4 DHCP，忽略上游 DNS |
| DHCP | `192.168.30.100-192.168.30.249`，网关和 DNS 均为 `192.168.30.1` |
| DNS | CoreDNS client namespace，经 nftables 把 LAN 的 TCP/UDP 53 转入 namespace |
| NAT | 仅离开 `eth1` 的 IPv4 流量 masquerade；LTNET 与站点 LAN 间保留源地址 |
| 串口 | UART0，`1500000 8N1`，无硬件流控 |
| 持久化 | FAT32 `/boot`、Btrfs `/nix`、tmpfs `/` |

`192.168.30.0/24` 是 H28K 自己管理的站点网络，不属于家庭
`home-lan`。设备暂放家中时，`eth1` 会从现有 `192.168.0.0/24` 获得一个动态地址；
迁到异地以后，WAN 仍使用 DHCP，不需要改变 LAN 地址。

## 硬件来源与边界

H28K 的公开资料显示两个千兆网口分别由 RK3528 集成 GMAC + RTL8211F 和 PCIe
RTL8111H 提供。上游 DTS 的别名把集成 GMAC 固定为 `ethernet0`；结合板卡文档，
本配置使用以下映射：

| 接口 | 物理用途 | Linux 驱动 | 指示灯 |
| --- | --- | --- | --- |
| `eth0` | LAN | `dwmac-rockchip` + `realtek` PHY | `amber:lan` |
| `eth1` | WAN | `r8169` + `rtl8168h-2.fw` | `blue:wan` |
| - | 系统状态 | `gpio-leds` | `green:status` heartbeat |

板卡存在 1/2/4 GiB RAM 和不同 eMMC 版本；实际焊接容量仍以首启的
`free -h`、`lsblk` 为准，配置不假定 eMMC 必然存在。当前 SD 镜像仅依赖 TF 卡。

参考来源：

- [HINLINK H28K 产品页](https://www.hinlink.cn/121.html)
- [Seeed LinkStar-H28K 硬件资料](https://wiki.seeedstudio.com/H28K_Datasheet/)
- [Linux Rockchip 已接收的 H28K DTS 提交](https://git.kernel.org/pub/scm/linux/kernel/git/mmind/linux-rockchip.git/commit/?id=145d4af4b204e1fb565a498c6c8f801525cc0a4e)
- [U-Boot Rockchip 构建与写盘说明](https://docs.u-boot.org/en/latest/board/rockchip/rockchip.html)

## 内核与 DTB

本仓锁定的 Linux 6.18.40 已包含 `rk3528.dtsi`、时钟、pinctrl、PM domain、
DesignWare Ethernet、PCIe、SD/MMC 和 USB 驱动，但它早于 H28K 板级 DTS 合入。
因此 `nixos/hardware/hinlink-h28k/` 携带上游提交
`145d4af4b204e1fb565a498c6c8f801525cc0a4e` 的补丁（含本地增量），并让
`linuxManualConfig.kernelPatches` 应用它。

最终只复制：

```text
rockchip/rk3528-hinlink-h28k.dtb
```

没有添加 flake input，也没有复制 Armbian、OpenWrt 或厂商镜像中的预编译 DTB。
锁定内核以后包含该提交时，可删除补丁中与上游一致的部分，但**必须保留 phy reset
本地增量**：H28K 板的 RTL8211F 复位线（gpio4 RK_PC2）上电未配置、默认被拉低，
而 phy 节点 `reset-gpios` 只在 PHY 被 MDIO 找到之后才执行，形成死锁（首次探测
必然 `MDIO device at address 1 is missing`，PHY 注册失败、eth0 无 link）。`&gmac1`
的 `snps,reset-gpios` + `snps,reset-delays-us` 让 stmmac 在 MDIO 扫描之前释放复位；
phy 节点因此不再声明 `reset-gpios`（同一 GPIO 的双消费者会被 gpiolib 以 -EBUSY
拒绝）。若上游修复了该板级问题，再删除增量并核对 DTB 哈希与真机行为。

### 上游跟进（2026-08 调研结论，暂不主动提交）

H28K 板级 DTS 的上游提交 `145d4af4b204e1fb565a498c6c8f801525cc0a4e` 已在
linux-rockchip for-next（Heiko Stuebner 2026-07-02 b4-ty 应用），无需重复提交。
phy reset 死锁修复暂不向上游提交，原因：

- 死锁可能是个体差异：作者板子的 RTL8211F RST# 大概率有板上上拉，本仓真机
  （pin146 上电读低、MDIO 全 0xFFFF）才触发；未确认其他 H28K 板子是否同样受影响。
- 方向冲突：`snps,reset-gpios` 是 stmmac deprecated 属性，社区主流是移回 phy 节点
  （标准 ethernet PHY reset binding），反向提交会被审阅者质疑。
- 上游合入后本仓保留增量即可正常工作，无紧迫性。

若未来确认死锁普遍（如其他用户反馈 `MDIO device at address 1 is missing`），
候选路径：在 linux-rockchip 邮件列表（To: Heiko Stuebner，Cc
linux-arm-kernel/linux-rockchip/linux-kernel/devicetree + DT 维护者）先发 RFC 说明
证据（dmesg 前后对比、pinmux 状态、PHY ID 0x001cc916），对齐方向后再提补丁；
或改用标准方向（phy 节点保留 `reset-gpios`，把 `gmac1_rstn_l` 上拉并入 `&gmac1`
的 `pinctrl-0` 提前释放复位，需重新验证上拉强度）。

内核沿用已在 R5C 验证的 Rockchip 手工配置。该配置已包含 H28K 所需的 RK3528
clock、Rockchip pinctrl/GPIO、PWM regulator、SDHCI/DW-MMC、DWMAC、Realtek PHY、
Rockchip PCIe/combphy、r8169、GPIO LED 和 netdev/heartbeat trigger。内核 derivation
在 x86_64 上使用 aarch64 交叉工具链，调度要求仍为 `big-parallel`；当前只有
`ml-builder` 宣告这一能力。

## U-Boot 与 SD 布局

锁定的 U-Boot 2026.07 已包含 `generic-rk3528_defconfig`。Nixpkgs 的 rkbin
`ecb4fcbe954edf38b3ae037d5de6d9f5bccf81f4c` 包含：

```text
rk3528_ddr_1056MHz_v1.13.bin
rk3528_bl31_v1.21.elf
```

它们被组合成单一 `u-boot-rockchip.bin`。依照 U-Boot 的 RK3528 文档，镜像把该文件
写到 sector 64（32 KiB）；第一个分区从 16 MiB 开始，避免覆盖引导载荷：

```text
SD card
├── 32 KiB: u-boot-rockchip.bin（TPL/SPL + U-Boot + BL31）
├── 16 MiB: FAT32 FIRMWARE -> /boot
└── partition 2: Btrfs NIXOS_NIX -> /nix

runtime
├── /      tmpfs
└── /nix   neededForBoot = true
```

这是 H28K 首次真机测试中风险最高的一层：mainline U-Boot 目前使用通用 RK3528
早期设备树，而不是 H28K 专用 defconfig。配置和 SD 控制器已从锁定源码确认，仍必须
以串口证明 BootROM、DDR、SD 和 extlinux 全部工作，不能在此之前写入板载 SPI/eMMC。

## 构建

在 `ml-builder` 的已提交工作树中先求值：

```bash
cd /nix/src/nixos-config
nix eval --raw \
  .#nixosConfigurations.h28k.config.system.build.sdImage.drvPath \
  --show-trace
```

再由用户启动耗时构建：

```bash
nix build \
  .#nixosConfigurations.h28k.config.system.build.sdImage \
  --out-link result-h28k \
  --print-build-logs \
  --show-trace \
  --option max-jobs 4
```

U-Boot derivation 显式要求 `aarch64-cross`，内核要求 `big-parallel`，二者都在
`x86_64-linux` 上运行交叉工具链，不会交给 H28K 或其他弱 ARM 板原生编译。

构建完成后：

```bash
IMAGE="$(find -L result-h28k/sd-image -name '*.img.zst' -print -quit)"
test -n "$IMAGE"
zstd -t "$IMAGE"
sha256sum "$IMAGE"
```

## 写卡与串口

写卡前必须再次核对目标是整张 SD 卡。macOS 示例中的 `diskN` 必须替换为实际设备：

```bash
diskutil list
diskutil unmountDisk /dev/diskN
zstd -dc /path/to/nixos-image-*.img.zst | \
  sudo dd of=/dev/rdiskN bs=16m
sync
diskutil eject /dev/diskN
```

串口为 3.3 V TTL；不要连接 VCC：

```bash
ls /dev/cu.usbserial-* /dev/cu.usbmodem* 2>/dev/null
tio -b 1500000 -d 8 -s 1 -p none -f none /dev/cu.usbserial-XXXX
```

首启串口必须看到完整层次：

```text
Rockchip BootROM
DDR/TPL
U-Boot 2026.07
Scanning mmc ...
读取 extlinux.conf、Image、initrd、rk3528-hinlink-h28k.dtb
Starting kernel ...
Linux earlycon on ff9f0000
挂载 /nix
systemd multi-user.target
```

## 首次接线与 SSH

有两条互不依赖的救援路径：

1. `eth1` 接现有家庭路由器，从 DHCP 租约中找到 H28K 的 WAN 地址，然后使用
   `ssh -p 2222 root@<WAN-DHCP-IP>`；防火墙只临时允许来源
   `192.168.0.0/24` 访问这个端口。
2. 电脑直连 `eth0`，手工设置 `192.168.30.2/24`，然后使用
   `ssh -p 2222 root@192.168.30.1`。

登录公钥来自本仓 secrets 的 `ssh/zhyi.nix`。镜像不会内嵌 SSH host 私钥；
OpenSSH 首启时在 `/nix/persistent/etc/ssh/` 生成并保存主机身份。

## 首启验收

先验证硬件和基础系统：

```bash
cat /proc/device-tree/model
free -h
lsblk -o NAME,SIZE,TYPE,FSTYPE,LABEL,MOUNTPOINTS
findmnt / /boot /nix
ip -br link
ip -4 -br address
lspci -nnk
ethtool -i eth0
ethtool -i eth1
systemctl --failed --no-pager
systemctl is-active dbus-broker sshd systemd-networkd
```

再从一台接在 LAN 口的客户端验证路由数据面：

```bash
ip -4 address
ip -4 route
dig @192.168.30.1 example.com
ping -c 3 192.168.30.1
ping -c 3 223.5.5.5
curl -4I https://example.com/
```

LED 和端口映射必须以真机结果复核：

```bash
ls -1 /sys/class/leds
cat /sys/class/leds/amber:lan/device_name
cat /sys/class/leds/blue:wan/device_name
cat /sys/class/leds/green:status/trigger
journalctl -b -u h28k-leds --no-pager
dmesg | rg -i 'rk3528|stmmac|rtl8211|r8169|rtl8168|pcie|mmc|error|fail'
```

至少完成一次拔电冷启动。只验证 `reboot` 不足以证明 BootROM、SD 和持久化布局可靠。

## SSH、SOPS 与 ZeroTier 正式化

初始 `host.nix` 故意保留：

```nix
ssh.ed25519 = null;
zerotier = null;
```

这样不会伪造主机身份。首启后依次执行：

```bash
cat /nix/persistent/etc/ssh/ssh_host_ed25519_key.pub
ssh-keygen -lf /nix/persistent/etc/ssh/ssh_host_ed25519_key.pub
zerotier-cli info
```

然后按[新主机接入规范](../getting-started/new-host-standard.md)完成：

1. 把真实 SSH host 公钥写入 `hosts/h28k/host.nix`；
2. 转成 age recipient，在 secrets 仓库加入 H28K 并完整 rekey；
3. 把真实 ZeroTier node ID 写入 `host.nix`，部署 controller 并授权；
4. 验证 `198.18.0.125` 和路由 `192.168.30.0/24`；
5. 确认 LTNET SSH 可用后，删除防火墙中的家庭 LAN 临时 SSH 放行；
6. 再决定是否继续保留 `manualDeploy = true`。路由器属于高风险节点，长期手动部署是
   合理选择。

在 `zerotier = null` 阶段，ZeroTier 服务仍会启动以生成 node ID，但邻居初始化服务
不会进入无限等待；node exporter 暂时只绑定 `127.0.0.1`。填入真实 ID 后，两者自动
恢复仓库的标准 LTNET 行为。SOPS 在完成 rekey 前失败属于预期首启门禁，不能用复制
其他主机私钥来消除。
