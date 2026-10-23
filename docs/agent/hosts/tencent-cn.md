# tencent-cn（Tencent Cloud CVM，上海）

`hosts/tencent-cn/*.nix` 不写注释，理由记录在本文件。

## 网络

- Tencent 给的公网 IPv6 是静态 /128；网关是子网路由器的固定 link-local（上海 CVM 用
  固定网关，与首尔 CVM 由实例 MAC 派生不同），机房不下发 RA 默认路由（`accept_ra`
  保持关闭）。
- mesh 默认 vhost 自带 snakeoil 证书；这里用 greencloud 同步下来的通配证书，让公网 TLS
  可验证、不必逐主机走一次签发（与 tencent 同一选择）。

## 硬件/主机元数据

- 存储布局按项目统一服务器架构：tmpfs `/`（impermanence）、独立 `/boot`、持久 btrfs
  `/nix`（`neededForBoot = true`）。BIOS 布局（安装环境确认 `test -d /sys/firmware/efi`
  为假）：2 MiB bios_grub + 1 GiB ext4 `/boot` + btrfs `/nix`；
  `boot.loader.grub.device = "/dev/vda"`。UUID 是 2026-09-23 在 Alpine RAM 安装环境用
  `blkid` 读的。
- 主机密钥 2026-09-23 安装前生成、Alpine RAM 安装阶段放进 `/nix/persistent/etc/ssh`
  （指纹 `SHA256:fx5n7rhOX9fLW8lEhREW9yrg5xBqxvaIECUE/Fs8Vs8`）；ZeroTier node ID 于
  2026-09-24 首启采集并在 greencloud 控制器上授权。
- 地域字段即使没有 dn42，server-role 的 BIRD 配置也会读取。
