# rkwifibt 学习笔记

## 1. 是什么

`rkwifibt` 是 Fruit-Pi/rkwifibt 的 fork（BSD-3-Clause，2 star，C，
2022-04 后停更）：Rockchip 平台 WiFi/BT 固件包（RKWifiBT）的镜像，
无 README，内容基本是 Rockchip 原始发布包。

## 2. 内容

- `firmware/` + `realtek/`：Realtek（RTL8723DS / RTL8821CS /
  RTL8822CS 等）和 Broadcom 固件；
- `bin/arm` / `bin/arm64`：预编译工具（dhd、wl、rtwpriv、rtlbtmp）；
- `S36load_*` / `S67wifi` / `bt_load_*`：init 脚本，加载 WiFi 模块、
  启动蓝牙固件；
- `src/`：WiFi 初始化、低功耗、TCP keepalive 等 C/C++ 源码
  （含 CY_WL_API 和 openssl include 副本）；
- `wpa_supplicant.conf`、`dnsmasq.conf`：AP 配置样例。

## 3. 对我们仓库的启发

- 我们不用 Rockchip WiFi/BT，不引入；
- 它和 hpe-ltfs 一样是“厂商固件包镜像”类仓库：用途是让 Nix
  打包能 fetch 固定源码/固件；这类仓库通常无 Nix 表达式，只做
  托管；
- 若 zhyi-packages 未来要支持 RK 板卡外设，可从这里取固件。

## 4. 参考

- [rkwifibt](https://github.com/nix-community/rkwifibt)
