# HINLINK H28K（RK3528）NixOS 路由器适配

本文记录 `h28k` 主机的首启镜像、双网口路由和正式入网门禁。2026-08-15 起设备已在线
运行（ZeroTier/LTNET 接入，`zerotier = "368d3cf42b"`），本文历史结论按"已由源码确认 /
已由真机验证"区分，不再以"可求值"当作验收标准。

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

H28K 内核使用 Nixpkgs 的 Linux 7.1（`linux_7_1`）：该版本的 `rk3528.dtsi`
已包含 H28K 板级 DTS 所需的 PCIe 节点（USB 节点仍缺失，因此携带的上游补丁去掉
USB 部分）。板级 DTS 本身尚未合入任何发布内核，仓库携带 Rockchip 维护者已接收
的上游提交 `145d4af4b204e1fb565a498c6c8f801525cc0a4e` 的补丁（含 phy reset
本地增量），并让 `linuxManualConfig.kernelPatches` 应用它。

最终只复制：

```text
rockchip/rk3528-hinlink-h28k.dtb
```

没有添加 flake input，也没有复制 Armbian、OpenWrt 或厂商镜像中的预编译 DTB。
锁定内核以后包含该提交时，可删除补丁中与上游一致的部分，但**必须保留 phy reset
本地增量**：H28K 板的 RTL8211F 复位线（gpio4 RK_PC2）上电未配置、默认被拉低，
而 phy 节点 `reset-gpios` 只在 PHY 被 MDIO 找到之后才执行，形成死锁（首次探测
必然 `MDIO device at address 1 is missing`，PHY 注册失败、eth0 无 link）。复位放到
`&mdio1` 总线级（mdio.yaml `reset-gpios` / `reset-delay-us` /
`reset-post-delay-us`），`__mdiobus_register()` 在扫描 PHY 前 assert→deassert；
phy 节点因此不再声明 `reset-gpios`（同一 GPIO 的双消费者会被 gpiolib 以 -EBUSY
拒绝）。该方案已按 RFC v2 在 7.1 真机验证：`PHY [stmmac-0:01] driver
[RTL8211F]`、`phy_id = 0x001cc916`。若上游修复了该板级问题，再删除增量并核对
DTB 哈希与真机行为。

内核沿用已在 R5C 验证的 Rockchip 手工配置。该配置已包含 H28K 所需的 RK3528
clock、Rockchip pinctrl/GPIO、PWM regulator、SDHCI/DW-MMC、DWMAC、Realtek PHY、
Rockchip PCIe/combphy、r8169、GPIO LED 和 netdev/heartbeat trigger。内核 derivation
在 x86_64 上使用 aarch64 交叉工具链，调度要求仍为 `big-parallel`；当前只有
`ml-builder` 宣告这一能力。

## 上游提交跟进

PHY 复位死锁修复以 RFC 形式提交 linux-rockchip 邮件列表，163 邮箱线程为主线：

| 版本 | 方案 | 时间 | Message-ID |
| --- | --- | --- | --- |
| v1 | `snps,reset-gpios`（MAC 节点） | 2026-08-03 | `20260803104646.26836-1-zyheihei_123@163.com` |
| v2 | MDIO 总线 reset（`&mdio1`） | 2026-08-04 | `178577533421.26919.15449256732994709630.h28k-rfc-v2@163.com` |

v1 曾因 Outlook 误发产生一个重复线程（根 Message-ID
`SJ2PR04MB851017E50140354C2F5B3FF3B5D52@SJ2PR04MB8510.namprd04.prod.outlook.com`）。
v2 发送时按邮件礼仪以 163 主线回复，并在重复线程回帖说明 supersede，避免
讨论继续分流。

维护者反馈：

- Andrew Lunn（回复在重复线程）：
  [d2780faf-54e8-4c0a-8070-93d36c91cb19@lunn.ch](https://lore.kernel.org/linux-rockchip/d2780faf-54e8-4c0a-8070-93d36c91cb19@lunn.ch/)：
  不要新增使用已废弃的 `snps,reset-gpios`，改用 mdio.yaml 的 reset 属性。
- Chukun Pan（回复在主线）：
  [20260803124000.840861-1-amadeus@jmu.edu.cn](https://lore.kernel.org/linux-rockchip/20260803124000.840861-1-amadeus@jmu.edu.cn/)：
  复位应由 U-Boot 处理（参考 OpenWrt commit
  [384127320e0b](https://github.com/openwrt/openwrt/commit/384127320e0b)），
  不建议硬编码 PHY ID（RTL8211F/YT8531 都可能）。

v2 按上述反馈收敛为 MDIO 总线级复位 + 不硬编码 PHY ID；U-Boot 侧（generic
RK3528 DT 未初始化该复位线）在 changelog 中说明为 out of scope。依据
`Documentation/process/coding-assistants.rst` 与
`generated-content.rst`，提交带 AI 标注：

```text
Assisted-by: Codex:gpt-5
```

并在 changelog 说明 AI 参与根因分析与方案、真机验证由人完成。当前状态：v2
已上线 lore（linux-rockchip 归档），等待维护者反馈。

**U-Boot 侧收敛（2026-08-15 已验证）**：mainline 的 dwc_eth_qos 只在执行网络命令时才
走 PHY 路径，且 `DWC_ETH_QOS_ROCKCHIP` 会 `select DM_ETH_PHY`，把 `phy_gpio_reset()`
编译成空 stub —— 即使 U-Boot 板级补丁在 DTS 里声明了 `reset-gpios`，开机流程也从来
不会释放 RTL8211F 复位（GPIO4 RK_PC2 上电默认拉低），Linux 首次 MDIO 扫描读不到 PHY，
eth0 呈 `MDIO device at address 1 is missing` / `cannot attach to PHY (-ENODEV)`。
仓库本地增量 `0002-h28k-release-phy-reset-gpio-hog.patch` 在 U-Boot DTS 加 gpio-hog
（GPIO bank probe 时把 RK_PC2 拉高，早于以太网初始化和 Linux 启动，与 CONFIG_NET 无关），
defconfig 加 `CONFIG_GPIO_HOG=y`。已真机验证：`PHY [stmmac-0:01] driver
[RTL8211F Gigabit Ethernet]`，eth0 千兆 link 正常，内核随后自行接管复位 GPIO
（debugfs 显示 `PHY reset` out hi）。U-Boot 侧改动以独立本地补丁叠加在 Chukun Pan
原版之上，原版补丁保持 verbatim。

- v2：https://lore.kernel.org/linux-rockchip/178577533421.26919.15449256732994709630.h28k-rfc-v2@163.com/
- supersede 说明：https://lore.kernel.org/linux-rockchip/178577533421.26919.15228893238527652331.h28k-rfc-v2-supersedes@163.com/

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

这是 H28K 早期首次真机测试中风险最高的一层（历史记录）：当时 mainline U-Boot 使用
通用 RK3528 早期设备树。2026-08-04 起已切换为板级 `hinlink-h28k-rk3528_defconfig`
（Chukun Pan 补丁），BootROM、DDR、SD、extlinux 与双网口均已在真机验证
（2026-08-15），可正常在线运行；仍不建议写入板载 SPI/eMMC，除非有明确需求。
U-Boot 只更新 SD 卡 sector 64 处的 `u-boot-rockchip.bin` 区域（约 9 MiB），
不需要整卡重写；写前先备份旧区域（如 `dd if=/dev/mmcblk0 bs=512 skip=64 count=18323`）。

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

## 网络调优（2026-08-16，参考 R5C 配方）

两个网口都是单队列（`dwmac-rockchip` 的 eth0、`r8169` 的 eth1），iperf3 基线
（rock5c ↔ h28k，家庭千兆交换）显示两个口本就贴千兆线速（P1 938-941 / P4 950-951
Mbit/s），没有吞吐缺口。因此只套用 R5C 配方里适用单队列的部分（
`docs/research/10-router-rx-queue-4.md`）：

- `hosts/h28k/performance.nix`：`netdev_budget 1200/30000`、`netdev_max_backlog
  5000`、`rps_sock_flow_entries 16384`（双口 × 单队列 × 8192 流深）、
  `flow_limit_table_len 16384`、16 MiB socket buffer；关闭 irqbalance；
  `h28k-rps` 服务（每分钟自愈定时器）每口单 RX 队列 RPS 铺满 4 核、XPS 同铺、
  eth0 IRQ→CPU0 / eth1 IRQ→CPU1、根 qdisc 换 `fq_codel`、双口 EEE off。
- eth1（r8169）的 `xps_cpus` 在接口重建后才出现且部分写入被内核拒绝（stat 通过、
  open 报 ENOENT），脚本对 sysfs 写入全部 best-effort（`|| true`），核心项
  （RPS/fq_codel/EEE/IRQ 亲和）不受影响。
- flowtable 未启用：7.1.5 内核缺 `CONFIG_NFT_FLOW_OFFLOAD`（与 R5C 的 6.18 内核
  配置有漂移），且当前负载下转发不缺卸载。

实测（调优后）：eth0 P4 反向重传 166 → 0，吞吐维持 938-951 Mbit/s 线速；
部署到系统后 `h28k-rps.service` active，状态经重启可自动恢复。

## SOPS / attic（2026-08-16 已解决）

- 根因：`.sops.yaml` 的 `&h28k` recipient 是用重刷前的旧 host key 生成的
  （`age1vgsmd…`），现场密钥（`age1d634874…`）不在 recipient 列表，
  `sops-install-secrets` 自首启失败，`/run/secrets/` 为空，attic 私有缓存的
  netrc 读取 token 缺失。
- 处理：`nixos-secrets` 修正 h28k recipient 并对全部 67 个 yaml rekey
  （`sops updatekeys`，注意需要管道喂 `y` 确认），推送 `main`；主仓库 bump
  secrets flake 输入；h28k 重新部署后 `sops-install-secrets` 成功，
  `/run/secrets/` 填充，attic `nix-cache-info` 从 401 → 200。
- 后续部署应改回正规 `nix copy` / colmena 流程（无需再绕 daemon 签名校验）。
