# Radxa ROCK 5C NixOS 适配

ROCK 5C 沿用 `opi5p` 已验证的 RK3588 vendor kernel、Mali CSF 和 reDroid
配置，但启动介质不同：ROCK 5C 没有已安装的 SPI NOR，因此每个 SD 卡镜像必须
自带 U-Boot。板卡始终使用独立的 `rock5c` 主机身份；迁移服务不复用
`ml-home-vm` 的主机名、地址、SSH key 或 ZeroTier 身份。

## 实现边界

- 主机身份：[`hosts/rock5c/`](../../../hosts/rock5c)
- 板级模块：[`nixos/hardware/rock-5c/`](../../../nixos/hardware/rock-5c)
- reDroid 主机配置：[`hosts/rock5c/configuration.nix`](../../../hosts/rock5c/configuration.nix)
- Linux DTB：`rockchip/rk3588s-rock-5c.dtb`
- U-Boot：Armbian `rock-5c` vendor 包（Radxa BSP + Armbian RK35xx 补丁）
- 串口：UART2，1500000 8N1

Linux 使用固定版本的 `gnull/nixos-rk3588` vendor kernel 包装。U-Boot 来自
仓库内固定的 Armbian `linux-u-boot-rock-5c-vendor` 包，Nix 解包时会分别校验
`idbloader.img` 和 `u-boot.itb`。最终镜像不依赖 Armbian 工作目录。

主线 U-Boot 2026.07 虽能加载 extlinux 和 vendor 6.1 内核，但会让 RK806 PMIC
和时钟处于不兼容状态。实机表现为 SPI 超时、MMC/GPU/RNG/PCIe 初始化失败、
RCU stall，最后触发 `Asynchronous SError`。因此不得把 Nixpkgs 主线 U-Boot
重新替换到这条 vendor 启动链。

## SD 卡启动布局

镜像保留前 32 MiB，并在 Rockchip 标准位置写入两个 U-Boot 阶段：

| 内容 | 扇区 | 字节偏移 |
| --- | ---: | ---: |
| `idbloader.img` | 64 | 32 KiB |
| `u-boot.itb` | 16384 | 8 MiB |
| `FIRMWARE` | 65536 | 32 MiB |

`FIRMWARE` 保存 extlinux、kernel、initrd 和唯一的 ROCK 5C DTB；第二分区是
持久化 Btrfs `/nix`，运行时 `/` 仍为 tmpfs。首次启动由
`rock5c-grow-nix.service` 自动识别 `/nix` 所在整盘并扩展第二分区，不依赖
设备恰好叫 `/dev/mmcblk0`。

## 主机身份

ROCK 5C 固定使用：

- host index `123`
- LAN 地址 `192.168.0.64`

`192.168.0.51` 属于已退役的原 x86 `ml-home-vm`（2026-08-03）。新板首次适配必须采集真实身份：

```bash
cat /proc/device-tree/model
cat /etc/ssh/ssh_host_ed25519_key.pub
ip -br link
ethtool -P eth0
zerotier-cli info
```

然后把 SSH host key、永久 MAC 和 ZeroTier ID 写回配置，并将网络匹配从临时
`eth0` 改成 `PermanentMACAddress`。完成冷启动、SSH、Mali 与 reDroid 验收后，
再决定是否移除 `manualDeploy`。

## 构建镜像

先只求值：

```bash
nix eval \
  .#nixosConfigurations.rock5c.config.system.build.sdImage.drvPath \
  --show-trace
```

求值通过后由构建机执行耗时构建：

```bash
nix build \
  .#nixosConfigurations.rock5c.config.system.build.sdImage \
  --out-link result-rock5c \
  --print-build-logs \
  --show-trace
```

写卡并上电后，串口应依次看到 DDR/TPL、Armbian vendor U-Boot、extlinux、kernel 和
`rk3588s-rock-5c.dtb` 的加载记录。若只看到 BootROM 重试，应先检查镜像开头的
U-Boot 数据，而不是修改 Linux 配置：

```bash
IMAGE="$(find -L result-rock5c/sd-image -name '*.img.zst' -print -quit)"
zstd -dc "$IMAGE" |
  dd bs=512 skip=64 count=32704 status=none |
  sha256sum
```

## Podman 镜像清理

ROCK 5C 没有可靠 RTC，冷启动后系统时间会发生大幅前跳。该主机因此单独禁用
Podman 的日历式自动 prune；否则 `podman system prune -af` 会在容器启动前把
离线导入的 MetaCubeXD 和 reDroid 镜像视为“未使用”并删除。此例外不修改公共
Podman 模块，镜像清理由管理员在确认容器引用关系后手动执行。
