# ARM 开发板 NixOS 适配手册

本文描述将一块新的 ARM64 开发板接入本仓库的通用流程。板卡专项参数应放在
`nixos/hardware/<board>/`，正式主机身份仍放在 `hosts/<hostname>/`；不要为了
硬件适配长期保留一个与正式用途重复的临时 host。

NanoPi R5C 的已验证实现见
[`nixos/hardware/nanopi-r5c/`](../../nixos/hardware/nanopi-r5c/) 和
[`nanopi-r5c.md`](./nanopi-r5c.md)。

## 1. 先拆分四层问题

ARM 板适配应按以下顺序推进：

1. BootROM、SPL/TPL 和 U-Boot 能初始化内存与启动介质；
2. U-Boot 能读取 kernel、initrd、DTB 和 extlinux 配置；
3. Linux 能进入 initrd、挂载目标文件系统并启动 systemd；
4. 正式主机的网络、SOPS、持久化和应用服务能够运行。

串口停在 `Starting kernel ...` 不等于 U-Boot 一定有问题；DHCP 没有租约也不等于
内核没有启动。每次只改变一层，并保存完整串口日志。

开始前先确定最终身份。若新板最终用于替换已有主机，应直接复用正式
`hosts/<hostname>/`，把板级差异收敛到 `nixos/hardware/<board>/`；只有在旧主机
必须与新板长期并行时才新增 host。适配过程可以使用最小镜像，但不要为同一台最终
主机永久留下 `board-test`、`board-install` 等重复配置。

## 2. 收集板级输入

至少确认以下信息：

| 项目 | 需要确认的内容 |
| --- | --- |
| SoC | 架构、启动流程、串口控制器和地址 |
| 内存初始化 | U-Boot 是否需要厂商 DDR blob 或 TPL |
| TF/eMMC/NVMe | 控制器、initrd 模块和 U-Boot 启动顺序 |
| DTB | Linux DTS 文件名及 `compatible` |
| U-Boot | defconfig、SPL/ITB 产物和写盘偏移 |
| 串口 | 3.3 V TTL、波特率、数据位、停止位和流控 |
| 网卡 | 驱动、稳定接口名、物理端口和 MAC 关系 |
| 指示灯 | DTS 中的 LED 名称、颜色、GPIO、默认触发器和网卡 PHY LED 能力 |
| 无线网卡 | PCIe/USB 枚举、驱动、固件、AP/HE 能力和监管域 |

优先检查当前锁定的 Nixpkgs 是否已经包含目标 DTS、U-Boot defconfig 和板级
derivation。只有上游缺失时才引入补丁或额外源码输入。

第三方发行版（例如 Armbian、OpenWrt、厂商镜像）适合用于：

- 确认硬件确实可用；
- 找到 DTS、defconfig、固件版本和写盘偏移；
- 对照串口日志与设备枚举结果。

它们不必成为最终 Nix 构建依赖。完成上游输入核对后，应让最终镜像只依赖
`flake.lock`、Nixpkgs 和本仓库声明的源码。

## 3. 建立硬件模块

推荐结构：

```text
nixos/hardware/<board>/
├── default.nix
└── make-*.nix          # 仅在需要自定义文件系统镜像时存在
```

正式主机通过自己的硬件配置导入：

```nix
{
  imports = [
    ../../nixos/hardware/disable-watchdog.nix
    ../../nixos/hardware/<board>
  ];
}
```

硬件模块负责：

- `nixpkgs.hostPlatform`;
- initrd 和运行时内核模块；
- kernel、DTB 和 console 参数；
- U-Boot derivation 与写盘偏移；
- `/boot`、`/nix` 和镜像分区布局。

主机模块负责：

- 主机名、地址和部署身份；
- SSH 公钥与 SOPS recipient；
- 网络角色和应用服务；
- ZeroTier、WireGuard、DHCP 等运行状态。

不要把临时救援地址、临时登录密钥或生产服务写入公共硬件模块。

## 4. 内核和设备树

本仓库通过 `lantian.kernel` 保留作者的内核包装和额外模块，不应直接绕过：

```nix
lantian.kernel = lib.mkForce pkgs.linux_6_18;
```

只复制目标 DTB，避免 FAT 启动分区被全部 ARM64 DTB 占满：

```nix
hardware.deviceTree = {
  name = "vendor/board.dtb";
  filter = "board.dtb";
};
```

构建前应在内核源码或 derivation 中确认：

```bash
test -f arch/arm64/boot/dts/vendor/board.dts
```

如果 DTS 尚未上游，优先以小补丁加入目标内核 derivation；不要长期从其他发行版
的输出目录复制一个来源不明的 DTB。

## 5. U-Boot 和写盘布局

优先复用同 SoC、同启动布局的 Nixpkgs U-Boot derivation，再覆盖目标 defconfig：

```nix
ubootForBoard = pkgs.ubootSimilarBoard.override {
  defconfig = "target-board_defconfig";
};
```

根据 SoC 文档或已验证镜像确定载荷偏移。分区起点必须位于所有裸写入载荷之后：

```nix
sdImage.postBuildCommands = ''
  dd if=${ubootForBoard}/idbloader.img of="$img" seek=64 \
    conv=notrunc status=none
  dd if=${ubootForBoard}/u-boot.itb of="$img" seek=16384 \
    conv=notrunc status=none
'';
```

不要凭其他板卡的布局猜偏移。刷写前后可以对整盘开头区域计算哈希，确认载荷没有
被分区或文件系统创建过程覆盖。

## 6. 本仓库的磁盘与持久化布局

物理设备沿用作者布局：

```text
整盘
├── SoC/U-Boot 裸写载荷
├── FAT32 FIRMWARE -> /boot
└── Btrfs NIXOS_NIX -> /nix

运行时：
/                  tmpfs
/nix               持久化 Btrfs
/nix/persistent    preservation 数据
```

`/nix` 必须设置 `neededForBoot = true`。镜像中至少预建：

```text
/nix/persistent/etc/machine-id
/nix/persistent/etc/ssh
/nix/var/nix/daemon-socket
/nix/var/nix/profiles/system
/nix/nix-path-registration
```

`machine-id` 目标应为空文件，由 systemd 首次启动写入唯一值。如果
`/etc/machine-id` 是指向不存在目标的 preservation 链接，D-Bus 会反复崩溃，
DHCP 也可能失败，所有依赖 D-Bus 的命令会表现为约 90 秒的卡顿。

启动分区要为 kernel、initrd、DTB 和 extlinux 留足空间。若构建日志出现
`Disk full`，应扩大 firmware 分区或过滤 DTB，不能只重试构建。

## 7. 串口和最小启动镜像

第一次启动只启用：

- 正确的 kernel、DTB、initrd 和 U-Boot；
- 一个明确的串口 console；
- SSH 和一个可找回的临时网络方案；
- `/boot`、`/nix` 与 preservation。

首启镜像必须显式加入操作者的临时 SSH 公钥。不要假定 Home Manager、SOPS 或正式
用户模块会间接提供救援入口。临时密钥应放在主机配置而不是硬件模块中，并在正式
密钥与 SOPS 验收后移除。

不要一开始合入完整 router/server/client 服务。先获取以下证据：

```text
U-Boot 读取 extlinux
U-Boot 读取 kernel/initrd/DTB
Starting kernel ...
Linux earlycon
initrd 挂载 /nix
systemd 启动
网卡获得地址
SSH 登录成功
```

同一串口不要同时由多个程序打开。macOS 写卡和串口操作见
[`nanopi-r5c-flash-and-serial.md`](./nanopi-r5c-flash-and-serial.md)，其中的设备名
和波特率需要替换为目标板实际值。

## 8. 构建和验证

配置修改先在本地提交、推送，再由 ARM64 构建机拉取：

```bash
# 本地
git push

# 构建机
cd /nix/src/nixos-config
git pull --ff-only
```

先求值，再执行耗时构建：

```bash
nix eval \
  .#nixosConfigurations.<hostname>.config.system.build.sdImage.drvPath \
  --show-trace

nix build \
  .#nixosConfigurations.<hostname>.config.system.build.sdImage \
  --out-link result-<hostname> \
  --print-build-logs \
  --show-trace
```

自定义内核选项会改变整个 kernel derivation，首次构建通常会完整重编内核。
Nixpkgs 的内核配置生成器可能输出大量：

```text
QUESTION: ...
GOT: ...
```

这是脚本自动读取 Kconfig 问题并写入答案，不是等待操作者输入。只要终端没有出现
真正的输入光标或构建错误，就不要按回车或 `Ctrl-C`。若只是新增一个驱动选项，
仍应确认它确实属于目标内核，并接受首次完整重编译的成本。

构建完成后检查：

```bash
IMAGE="$(find -L result-<hostname>/sd-image -name '*.img.zst' -print -quit)"
test -n "$IMAGE"
sha256sum "$IMAGE"
zstd -t "$IMAGE"
```

写卡前再次确认目标是整盘设备。首次启动至少验收：

```bash
cat /proc/device-tree/model
findmnt / /boot /nix
cat /etc/machine-id
ip -br link
ip -br address
systemctl is-system-running
systemctl --failed --no-pager
systemctl is-active dbus-broker sshd
```

还应完成一次断电冷启动，而不只测试 `reboot`。

## 9. 正式服务启用前的门禁

不要在“内核能启动”后立即一次性启用完整 router/server/client 配置。至少先通过：

```bash
systemctl is-active dbus-broker sshd
test -s /nix/persistent/etc/ssh/ssh_host_ed25519_key
systemctl status sops-install-secrets.service --no-pager
systemctl --failed --no-pager
```

新增 SOPS 密钥时还必须在构建机验证解密后的数据类型。数字形式的密码需要在 YAML
中明确作为字符串保存，否则 sops-nix 可能拒绝安装：

```bash
sops decrypt --output-type json path/to/secret.yaml |
  jq -r '.["key-name"] | type'
```

预期结果应与消费模块一致，例如密码通常是 `string`。提交加密仓库后，必须更新
主配置的 `flake.lock`，再重新求值；仅修改 secrets 仓库而不更新锁文件不会生效。
诊断时不得把解密后的明文打印到日志或聊天中。

关键联网服务需要单独验证其失败传播关系。以路由器为例：

```bash
systemctl list-dependencies pppd-wan.service
systemctl is-active pppd-wan.service
ip -4 route
ping -c 3 223.5.5.5
```

部署会主动停止并重启服务。如果 PPPoE、DHCP 或 SSH 依赖一个失败的 secrets 服务，
在线切换可能同时失去外网和管理入口。因此正式部署前应先验证 secrets derivation，
并保留串口或本地 LAN 救援路径。

## 10. 从救援配置切换到正式主机

硬件验证完成后，将板级模块导入正式 host，并移除重复的临时 host。正式切换前迁移：

- `/nix/persistent/etc/ssh/` 中的 SSH host keys；
- SOPS 对应的 age 身份；
- ZeroTier/WireGuard 身份；
- DHCP leases 和确有必要的应用状态。

生产地址切换前必须确认物理 WAN/LAN 端口映射。不要让旧设备和新设备同时使用网关
地址，也不要把普通测试镜像直接在线切换成不同的根文件系统架构。

切换路由器时还应按固定顺序验收：

1. 串口保持可用，旧网关尚未关闭；
2. 新板以临时地址验证两个物理网口、DNS、DHCP、NAT 和 PPPoE；
3. 停止旧网关，避免两个设备同时占用正式地址；
4. 新板切换正式地址并从 LAN 客户端验证 IP、DNS、HTTPS；
5. 观察一次 PPPoE 重拨和一次断电冷启动；
6. 最后再装回机壳并移除临时密钥。

不要只用路由器本机 `ping` 判断成功；必须从至少一台 LAN 客户端确认默认路由、
DNS 和 HTTPS 都经过新路由器。

## 11. 外设和指示灯应后置

Wi-Fi、状态灯和 PHY LED 应在基本网络稳定后适配：

- 用 `lspci -nnk`、`iw list` 确认无线驱动、AP 模式、HE/Wi-Fi 6 与频段能力；
- hostapd 负责把无线接口切换到 AP 模式时，不要让 systemd-networkd 提前把仍处于
  managed 模式的接口加入 bridge；
- GPIO LED 的颜色和用途以 DTS 与 sysfs 名称为准，流量闪烁优先使用
  `ledtrig_netdev`；
- 网口双色灯可能由 PHY/网卡驱动控制。优先启用上游驱动提供的 LED class 支持，
  重启后逐个测试物理映射，不要直接写未验证的私有寄存器。

每项外设改动都应先求值，再由用户执行耗时构建和部署；涉及内核配置的变更需要
重启后才能验收。

## 12. 脱离第三方构建框架的判定

满足以下条件即可认为最终 NixOS 构建已脱离 Armbian 或厂商构建框架：

1. `flake.nix`、硬件模块和 package derivation 不引用其仓库或产物路径；
2. kernel DTS 来自锁定的内核源码或仓库内补丁；
3. U-Boot 和所需固件由 Nix derivation 获取并构建；
4. 镜像分区、文件系统和引导载荷全部由 Nix derivation 生成；
5. 清空第三方工作目录后仍能在干净构建机完成求值和构建。

第三方文档和历史哈希可以继续保留作为验证证据，但必须明确标注为参考而非输入。
