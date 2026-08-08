# 立创泰山派（`taishanpi`）NixOS 适配

本文记录立创泰山派 1M（RK3566，2+16）的 TF 卡启动与 NixOS 基础配置。主机名为
`taishanpi`。板卡**无板载有线网卡**，联网只走 USB 无线网卡（rtw88）；首登必须
走串口。MIPI 3.1 寸屏（ST7701 800×480）通过 DSI overlay 适配。

## 当前启动契约

| 层级 | 当前选择 |
| --- | --- |
| SoC | Rockchip RK3566，aarch64-linux，4 × Cortex-A55 |
| RAM | 2 GiB LPDDR4 |
| Linux | 主线 Linux 6.18.40，由 ml-builder 交叉编译（含 `st7701-panel-lckfb-31inch.patch`） |
| DTB | 主线 `rockchip/rk3566-lckfb-tspi.dtb` + DSI overlay（`rk3566-taishanpi-dsi31-overlay.dts`） |
| U-Boot | Nixpkgs `ubootOrangePi3B.override { defconfig = "generic-rk3568_defconfig"; }` |
| 串口 | UART2 / `ttyS2`，**1500000**-8-N-1，无流控，MMIO `0xfe660000`（uart2m0：GPIO0_D0=RX、GPIO0_D1=TX） |
| 网络 | 仅 USB 无线网卡（rtw88_usb，`wlan0`）；无有线网卡（无 GMAC） |
| 存储 | microSD：FAT32 `/boot`、Btrfs `/nix`、tmpfs `/`；eMMC 需先清除才能从 TF 引导 |
| 屏 | LCKFB-mipi-3.1inch-screen（Sitronix ST7701，800×480，2-lane DSI），驱动见上 |
| 无线 | 板载 SDIO AP6212 后置（无 firmware，不启用）；USB 无线网卡为主 |

启动链：BROM → U-Boot SPL（`Trying to boot from MMC2`=TF 卡）→ 主线 U-Boot →
extlinux → NixOS。**eMMC 里若有官方 Android（U-Boot 2017.09 + Linux 4.19），
BROM 优先从 eMMC 引导，TF 卡镜像不会加载**。必须先清 eMMC 引导区
（见下方「eMMC 清除」）。

## 镜像布局

Rockchip BROM 从卡头 32 KiB 读 idbloader、8 MiB 读 U-Boot：

```text
microSD
├── 0x0        MBR/GPT
├── 0x8000     (64 扇区) idbloader.img
├── 0x1000000  (16384 扇区) u-boot.itb
├── 分区 1     FAT32 /boot (extlinux + kernel + dtb + dtbo)
└── 分区 2     Btrfs /nix (持久化)
```

`postBuildCommands` 用 `sfdisk --activate` 与 `dd seek=` 写入 idbloader/U-Boot，
与鲁班猫 1（RK3566）同一模式。烧录方式：解压 `*.img.zst` 后整盘写入 TF 卡。

## eMMC 清除（首次必做）

若板载 eMMC 有官方 Android，BROM 优先引导它。串口进 U-Boot 后：

```
=> mmc dev 0
=> mmc erase 0 0x8000     # 擦除前 16MB（覆盖 idbloader/U-Boot 引导区）
=> reset
```

重启后 SPL 显示 `Trying to boot from MMC2`（TF 卡）即为成功。清除后 eMMC 不再
参与引导，TF 卡镜像正常加载。

## 串口

- 调试串口 = UART2（`ttyS2`），波特率 **1500000**（非标准）。
- 物理引脚：GPIO0_D0=UART2_RX、GPIO0_D1=UART2_TX（板边 4pin 排针，丝印
  UART_TX/UART_RX/GND/VCC，VCC 不接）。
- macOS 读取：`tio /dev/cu.usbmodem* -b 1500000`。
- **macOS 限制**：系统 termios 最高只支持 230400，`stty`/Python `termios` 无法
  设置 1500000；`tio` 内部用自定义波特率所以可用。后台保持监听需给 tio 伪终端
  （`pty.fork()`），否则 tio 检测到 stdin 非 tty 立即退出。脚本：
  `tools/taishanpi/tio-pty.py`（输出落 `/tmp/taishanpi-boot.log`）。
- 串口读写辅助：`tools/taishanpi/send-serial.py`（向 `tty` 设备写命令）。

## root 登录（重要：仓库统一密钥，勿用 initialPassword）

仓库 `nixos/minimal-components/users.nix`（minimal 全量导入）统一管理用户：

- `users.mutableUsers = false`；
- `root` 与 `zhyi` 的 `hashedPassword` 都是 `lib.mkForce unixHashedPassword`
  （secrets flake 的 `glauth-users.nix` 里 `zhyi.passBcrypt`，bcrypt）。

**踩坑**：给 taishanpi 加 `users.users.root.initialPassword = "..."` 是错的——
`mutableUsers=false` 时 activation 会用统一 `hashedPassword` 覆盖，且
`initialPassword` 与 `hashedPassword` 同设会触发求值冲突。root 密码就是统一
bcrypt 的明文，不要重复设置。

串口登录脚本 `tools/taishanpi/login-serial.py` 不硬编码密码：优先读取
`TAISHANPI_ROOT_PASSWORD` 环境变量，未设置时在终端交互输入。

## 首启登录：预置 WiFi + SSH（不走串口密码）

Taishan Pi 无有线网卡，首启登录用**预置 WiFi + SSH**（仓库标准路径），不是
串口密码：

- `networking.wireless`（wpa_supplicant）预置 SSID/PSK 明文（测试期；后续
  迁 sops secret）；
- `systemd.network.networks."10-taishanpi-wlan"` 管 wlan0 DHCP；
- SSH 全局启用（端口 2222，root 用 zhyi 公钥，`PermitRootLogin=prohibit-password`）；
- **不需要** securetty 放行：hardening 的 `pam_securetty` 默认禁 root 串口
  密码登录，但我们不走串口密码，无需特例。之前加的
  `environment.etc.securetty.text` 特例已移除。

`networking.wireless` 生成的 `wpa_supplicant` 服务默认无 Restart 属性，会触发
仓库 `minimal-policies/ensure-service-restart` 断言，需显式设置
`systemd.services.wpa_supplicant.serviceConfig.Restart = "always"`。

## root 串口登录（securetty 特例）

`nixos/minimal-components/hardening.nix` 默认把 `/etc/securetty` 置空并在 login
PAM 加 `pam_securetty.so`（requisite）→ **root 在任何 tty（含 ttyS2）密码登录
都会被拒**，报「系统错误/登录错误」。lubancat1 等 host 不碰它是因为走 SSH
（root 用 zhyi 公钥）。taishanpi **只有 WiFi、首登必须走串口**，是仓库唯一需要
放行串口 root 登录的特例，在 `hosts/taishanpi/configuration.nix` 里：

```nix
environment.etc.securetty.text = lib.mkForce ''
  ttyS2
'';
```

（hardening.nix 的 securetty 是普通优先级，host 需 `lib.mkForce` 覆盖；PAM 的
`login.text` 是 `mkDefault`，securetty 非空后 pam_securetty 放行 ttyS2。）

## MIPI 3.1 寸屏（ST7701 800×480）

- 面板：Sitronix ST7701，800×480，2-lane DSI，RGB888（驱动写 `0x3A 0x70`）。
- 内核 patch：`pkgs/taishanpi-kernel/st7701-panel-lckfb-31inch.patch`
  （compatible `lckfb,3.1-inch-st7701`），GIP 序列来自庐山派 K230 SDK 的
  `st7701_480x800_init`。
- DSI overlay：`pkgs/taishanpi-kernel/rk3566-taishanpi-dsi31-overlay.dts`。
- 接线（**来自官方 BSP dtsi `tspi-rk3566-dsi-v10.dtsi`，勿用推测值**）：

| 项 | 值 |
| --- | --- |
| 背光 | `pwm5`（25000 ns），`pwm-backlight` |
| panel reset | `gpio3 RK_PC1`（active low） |
| lane-rate | `rockchip,lane-rate = <480>` |
| VOP 路由 | **VP1**（主线 vp0 已被 HDMI 占用；官方 SDK 用 vp0 是 Android 定制） |

**踩坑**：最初 overlay 用了推测的 `pwm1`/`gpio1 PA5/PA6`/VP0——全部错误。
对照官方 wiki「MIPI 4 寸长屏转接板」页 + SDK dtsi 后修正为 pwm5/PC1/VP1。

- `hardware.deviceTree.overlays` 必须用 submodule 格式（`{ name; dtsFile; }`）：
  裸路径会被当作**预编译 dtbo** 导致 `FDT_ERR_BADMAGIC`（NixOS 对裸 path 的
  coercedTo 默认 `dtboFile`）。
- 实机待校准：mode 的 hsync/hfp/hbp 是 ST7701 典型值（vbp=16/vfp=2 来自 K230
  序列），需实机 `modes` 校准；若色偏需核对 RGB888 vs RGB666（K230 用 0x50）。

## 踩坑清单（适配过程修正记录）

1. **root 密码**：勿用 `initialPassword`，走统一 bcrypt（见上）。
2. **securetty**：勿忽略 hardening 的 PAM 拦截，taishanpi 需显式放行 ttyS2。
3. **DSI 引脚**：勿用推测值，以官方 BSP dtsi / wiki 为准（pwm5、gpio3 PC1）。
4. **overlay 格式**：`dtsFile` submodule，裸路径会当 dtbo。
5. **eMMC 优先级**：TF 卡镜像烧了也要先清 eMMC 引导区。
6. **kernel patch**：panel patch 必须从干净内核源码生成真实 diff（手写 patch
   上下文易 malformed，`patch --dry-run` 验证）。
7. **串口波特率**：1500000 非标准，macOS 仅 tio/pty 方案可行，stty/Python
   termios 直接设失败。
