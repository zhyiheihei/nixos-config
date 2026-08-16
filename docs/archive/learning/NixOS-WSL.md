# NixOS-WSL 学习笔记

## 1. 是什么

`NixOS-WSL` 是 nzbr 维护的“在 Windows Subsystem for Linux 上跑
NixOS”的模块集（Apache-2.0，3039 star，2026-08 仍在活跃）。发布
物是 `nixos.wsl` rootfs 镜像：

```powershell
wsl --install --no-distribution
# 下载 nixos.wsl 后双击（WSL >= 2.4.4）
wsl -d NixOS
```

文档在 nix-community.github.io/NixOS-WSL。

## 2. Flake

- `nixosModules.wsl`：import 整个 `modules/`，并把
  `wsl.version.rev` 指向 flake 自身 rev；
- `nixosConfigurations.default`（x86_64）/ `aarch64`：构建 release
  rootfs tarball；默认启用 `wsl.enable`、欢迎提示、nixpkgs
  channel 链接，`stateVersion` 跟随 release；
- `packages`：`utils` / `staticUtils`（Rust：shell_wrapper、shim、
  split_path，负责 PATH/启动 shim）、`docs`（mdbook）；
- `checks`：nixpkgs-fmt、nixpkgs-input、options-doc、rustfmt、
  side-effects、username、utils 测试。

## 3. 模块

- `wsl-conf.nix` / `wsl-distro.nix`：WSL 配置与发行版注册；
- `interop.nix`：WSL interop（Windows 命令互操作）；
- `docker-desktop.nix` / `usbip.nix` / `ssh-agent.nix` / `welcome.nix` /
  `recovery.nix` / `version.nix`：配套场景；
- `build-tarball.nix`：生成可分发的 rootfs。

## 4. 对我们仓库的启发

- 我们的主机不跑 WSL，不引入；
- 它是“给特殊运行环境做 NixOS 发行镜像”的样例：模块化 +
  checks + mdbook 文档 + release 分发，和我们的镜像构建思路一致；
- 需要给 Windows 用户分发 NixOS 时可复用。

## 5. 参考

- [NixOS-WSL](https://github.com/nix-community/NixOS-WSL)
