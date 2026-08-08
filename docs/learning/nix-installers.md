# nix-installers 学习笔记

## 1. 是什么

`nix-installers` 为旧式、命令式 Linux 发行版构建 Nix/Lix 引导包，
使用发行版原生格式（deb / rpm / pacman）。MIT 协议，138 star。

## 2. 思路

- 先把预填充的 Nix store 做成 `nix-root.tar.xz`，塞进 deb/rpm/
  pacman 包；
- 安装后 hook 在 `postinstall` 时解包到 `/nix/store`，创建
  default/system profile、channel、`/root/.nix-channels`，并
  `systemctl enable nix-daemon`；
- 附带 SELinux policy（`selinux/nix.te` + `nix.fc`），安装后
  `semodule -i` + `restorecon -FR /nix`；
- 卸载时靠包管理器 hook 清理痕迹；
- 目标是“一次性引导”，之后交给 Nix 自管。

## 3. 实现

- `buildNixTarball`：用 `closureInfo` 的 registration 调
  `nix-store --load-db` 建 store 数据库，写 default/system profile
  和 manifest.nix，再用 sqlite 重置 `registrationTime` 保证可复现，
  最后以确定顺序/时间戳打 tar.xz；
- `buildLegacyPkg`：fakeroot + fpm 生成 deb/rpm，pacman 用
  libarchive + zstd；支持 Nix 和 Lix 两种实现；
- `rootfs` 带 `/etc/profile.d/nix-env.sh`，并预留 daemon socket
  目录。

## 4. CI

- `ci.yml`：`nix flake check`，然后构建 `nix.deb` / `lix.deb`，
  在 ubuntu runner 上 `dpkg -i` 安装，再跑
  `nix-shell -p hello --run hello` 做真实安装验证；
- `gh-pages.yml`：把预构建安装包发布到 GitHub Pages
  （nix-community.github.io/nix-installers）。

## 5. 对我们仓库的启发

- 我们主机都是 NixOS，不需要这类引导包；
- 如果以后要在非 NixOS VPS 上快速装 Nix，用这些原生包比官方
  install script 更适合自动化；
- “预填充 store + 确定化 tarball + 安装后真实测试”是值得借鉴的
  发布流程。

## 6. 参考

- [nix-installers](https://github.com/nix-community/nix-installers)
- [预构建安装包](https://nix-community.github.io/nix-installers/)
