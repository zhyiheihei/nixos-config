# taishanpi（泰山派，2 GiB，Wi-Fi 首启）

低功耗小主机：首启只走 Wi-Fi，MIPI 面板 + 39pin 扩展板千兆口。
`hosts/taishanpi/*.nix` 不写注释，理由记录在本文件。

## 登录与首启

- 不覆盖 root 密码：`users.nix`（minimal）用 secrets flake 里的统一 bcrypt 密码给 root
  和 zhyi（`users.mutableUsers = false`）。
- `hardening.nix` 会清空 `/etc/securetty` 并给 login 加 `pam_securetty`，默认任何 tty
  都不能 root 登录。本板没有有线网卡、首启只能走串口控制台，所以显式放行 `ttyS2`。
- `ssh-harden.nix` 让 sshd 用 `/nix/persistent/etc/ssh` 的主机密钥，而全新 sdImage 只
  建了目录：必须在 sshd 启动前把密钥准备好，否则首启唯一的入口只剩串口。

## 网络

- 没有有线网卡，唯一上行是 USB Wi-Fi 适配器（`rtw88_usb`，`wlan0`），用
  `wpa_supplicant` + `systemd-networkd` 拉起；WPA 口令在第一版 bring-up 镜像里是明文，
  之后要迁到 sops secret。
- `systemd-networkd` 负责 `wlan0` 的地址（DHCP），`wpa_supplicant` 负责关联；minimal
  配置已启用 networkd。
- 39pin 扩展板的千兆口（GMAC1 + RTL8211F，DTS 补丁启用）优先于 Wi-Fi：给 `eth0` 更低
  的 `RouteMetric`，插线走 eth，拔线自动回落 wlan。链路偶发闪断（FPC 排线信号完整性，
  稳定期完全健康），DHCP 用更快的重试节奏让租约在闪断间隙内收敛。
- 以太网 MAC 固定：GMAC 没有持久来源，内核每 boot 随机生成，会把 router 的 ARP/租约
  表刷满随机 MAC。
- `wpa_supplicant` 由 `networking.wireless` 生成，默认不带 `Restart`，而
  minimal-policies 的 ensure-service-restart 断言要求每个启用服务都有 `Restart`；
  `RestartSec` 也不能是 systemd 默认的 100ms（b1383d16 的断言）。
- 内核无线 ioctl 与 NL80211 需要真实的 `/proc` 视图和 netlink。

## 电源与硬件

- 板载 2 GiB 内存：zram 只提供 NixOS 激活所需的一点余量，不把这台低功耗板子当构建机。
- MIPI 面板由 taishanpi 的硬件模块加 DSI overlay；`zramSwap` 已由 minimal 的 hardening
  配置启用（zstd，50%），本文件不重复定义。
- `host.nix` 记录本板只经 Wi-Fi bring-up、没有有线网卡；在 Wi-Fi、MIPI 面板和 SSH
  验证通过之前不要并进批量部署。
