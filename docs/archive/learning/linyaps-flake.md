# linyaps-flake 学习笔记

## 1. 是什么

`linyaps-flake`（wineee 维护，MIT，8 star）是
SamLukeYes/linglong-flake 的 fork：在 NixOS 上部署
[Linglong/linyaps](https://linglong.org.cn/) 容器应用生态。2025-12
已归档——README 开头写明 **NixOS 25.11 起 linyaps 已合并进上游
nixpkgs**（[NixOS/nixpkgs#442883](https://github.com/NixOS/nixpkgs/pull/442883)），
使命完成。

## 2. 包

- `linyaps`（1.9.10）：主包管理器（CMake + Qt6，依赖 ostree、
  libarchive、gpgme、fuse3 等）；打补丁修 host 路径、desktop
  文件、ostree 仓库里的客户端路径常量；
- `linyaps-box`（2.1.0）：linyaps 用的简单 OCI runtime
  （libseccomp 开启 seccomp）。

## 3. NixOS module

`services.linyaps.enable`（默认 true）：

- 装 `linyaps` / `linyaps-box`，加
  `environment.profiles = [ "/var/lib/linglong/entries" ]`；
- polkit、字体目录、dbus 包、systemd 包与 tmpfiles 一并挂上；
- 建 `deepin-linglong` 系统用户/组。

`vm/` 里还有 QEMU 测试配置（LXQt 桌面 + 自动登录 + SSH），用于
手工验证。

## 4. 对我们仓库的启发

- 我们不跑 Linglong 应用，不引入；上游已合并，直接用 nixpkgs
  的 `linyaps` 即可；
- 它和 kde2nix、browser-previews 类似：临时 flake 承担“先于
  nixpkgs 提供某个生态”，合并后归档；
- “容器运行时（ll-box）+ 包管理器 + systemd/dbus/tmpfiles 集成
  + 测试 VM”是桌面应用容器化打包的完整样板。

## 5. 参考

- [linyaps-flake](https://github.com/nix-community/linyaps-flake)
