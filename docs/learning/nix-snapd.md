# nix-snapd 学习笔记

## 1. 是什么

`nix-snapd` 把 [snapd](https://github.com/canonical/snapd)（2.67）
打包给 Nix/NixOS 使用，并提供 `services.snap` NixOS module。74 star。

## 2. 使用

```nix
modules = [
  nix-snapd.nixosModules.default
  { services.snap.enable = true; }
];
```

选项：`snapBinInPath`（把 `/snap/bin` 加进 PATH）、`desktopFiles`
（桌面文件 + XDG_DATA_DIRS）。

## 3. 实现

- 用 `buildGoModule` 构建 snapd，`nixify.patch` 把
  `/etc/systemd/system` 改成 `/var/lib/snapd/nix-systemd-system`
  并放开 snap-confine 路径校验；
- `bubblewrap-insecure.patch` 去掉 `PR_SET_NO_NEW_PRIVS`，再放到
  `buildFHSEnvBubblewrap` 里，让 snap-confine 能完成 setuid 流程；
- snap-confine 拆成三个阶段：Python 包装 → NixOS
  `security.wrappers` 的 setuid wrapper → FHS 环境内执行真实
  snap-confine；
- snapd 启动时把 nix-systemd-system 下的 unit 以 transient
  systemd 方式拉起，绕过 NixOS 不可变 `/etc/systemd`；
- 提供 xdg-open wrapper，让 snap 内的 Launcher 能打开桌面程序。

## 4. CI

- `nix.yml`：DeterminateSystems flake-checker + `nix build` +
  `nix flake check`；
- `flakehub-publish-rolling.yml`：推 main 即发布 FlakeHub rolling；
- 每周自动更新 flake.lock。

## 5. 对我们仓库的启发

- 我们 NixOS 主机不跑 snap，不需要引入；
- 它是“把外部包管理器/服务适配到 NixOS 不可变系统”的典型例子：
  setuid wrapper、FHS 环境、transient systemd unit 都是常用手段。

## 6. 参考

- [nix-snapd](https://github.com/nix-community/nix-snapd)
- [snapd](https://github.com/canonical/snapd)
