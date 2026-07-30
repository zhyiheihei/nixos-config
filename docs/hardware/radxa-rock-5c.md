# Radxa ROCK 5C NixOS 适配

`rock5c` 沿用 `opi5p` 已验证的 RK3588 vendor kernel、Mali CSF 和 reDroid
配置，但启动介质不同：ROCK 5C 没有已安装的 SPI NOR，因此每个 SD 卡镜像必须
自带 U-Boot。

## 实现边界

- 主机身份：[`hosts/rock5c/`](../../hosts/rock5c/)
- 板级模块：[`nixos/hardware/rock-5c/`](../../nixos/hardware/rock-5c/)
- RK3588 共用 reDroid 模块：
  [`nixos/hardware/rk3588-redroid.nix`](../../nixos/hardware/rk3588-redroid.nix)
- Linux DTB：`rockchip/rk3588s-rock-5c.dtb`
- U-Boot defconfig：`rock-5c-rk3588s_defconfig`
- 串口：UART2，1500000 8N1

Linux 和 U-Boot 均使用当前固定源码中已有的 ROCK 5C 支持。最终镜像不依赖
Armbian 工作目录；`gnull/nixos-rk3588` 只提供已经固定哈希的 vendor kernel
Nix 包装，实际内核源码同样由 Nix derivation 获取。

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

## 初始主机状态

适配阶段使用：

- host index `123`
- LAN 地址 `192.168.0.64`
- `manualDeploy = true`

首次成功启动后必须采集真实身份：

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

写卡并上电后，串口应依次看到 DDR/TPL、主线 U-Boot、extlinux、kernel 和
`rk3588s-rock-5c.dtb` 的加载记录。若只看到 BootROM 重试，应先检查镜像开头的
U-Boot 数据，而不是修改 Linux 配置：

```bash
IMAGE="$(find -L result-rock5c/sd-image -name '*.img.zst' -print -quit)"
zstd -dc "$IMAGE" |
  dd bs=512 skip=64 count=32704 status=none |
  sha256sum
```
