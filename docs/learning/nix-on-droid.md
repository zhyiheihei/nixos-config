# nix-on-droid 学习笔记

## 1. 是什么

`nix-on-droid` 是 t184256 / Gerschtli 维护的项目：在 Android 设备上
以单 App 安装方式提供 Nix 环境（F-Droid 包 `com.termux.nix`）。
MIT，2111 star，2026-03 仍在活跃。它不是完整 NixOS，而是把
nixpkgs 的（预编译）软件直接装进 Android；**不需要 root / 用户
命名空间 / 关 SELinux**，靠 `proot` 等技巧实现；只用 aarch64。

## 2. 组成

1. Nix 表达式生成 **bootstrap zipball**（安装 Nix 包管理器 +
  `nix-on-droid` 可执行文件）；
2. 设备上的 **模块系统**：`~/.config/nixpkgs/nix-on-droid.nix`
   声明式配置（`environment.packages`、`system.stateVersion` 等），
   `nix-on-droid switch` / `rollback` 激活；
3. 终端 App 是 [nix-on-droid-app](https://github.com/nix-community/nix-on-droid-app)
   （Termux 终端 fork）。

## 3. Flake

- `lib.nixOnDroidConfiguration`：从 `modules/` 构建设备配置，支持
  home-manager 集成；旧参数已删除；
- `packages`：`bootstrapZip-<arch>`、`proot-termux`、
  `android-integration` 等（用固定 nixpkgs-for-bootstrap 保证
  可维护）；
- `apps.deploy`：发布 zipball 到远程；overlay 提供自定义包；
- checks：nix-formatter-pack（deadnix/nixpkgs-fmt/statix）。

## 4. 对我们仓库的启发

- 我们不跑 Android，不引入；
- “proot 无 root 装 Nix + 模块化配置 + bootstrap zipball”对
  Android/容器等受限环境有参考价值；
- 它和 nix-on-droid-app（已学）是配套双仓库。

## 5. 参考

- [nix-on-droid](https://github.com/nix-community/nix-on-droid)
