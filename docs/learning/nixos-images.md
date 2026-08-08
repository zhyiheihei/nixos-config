# nixos-images 学习笔记

## 1. 是什么

`nixos-images` 每周自动构建 NixOS 镜像，补充官方 Hydra 镜像，提供三类产物：

- ISO 安装镜像；
- kexec tarball（从现有 Linux 直接启动 NixOS 安装器）；
- netboot 镜像（PXE/iPXE 网络启动）。

## 2. 特点

- ISO 默认开启 SSH，支持远程安装；
- 随机 root 密码，显示二维码；
- 内置 IWD 配置 WiFi；
- kexec 保留 SSH host key 和网络配置；
- 与 `nixos-anywhere` 配合可无人值守安装。

## 3. 与我们仓库的关系

`nixos-anywhere` 的 kexec 安装就依赖这类镜像；`nix-community/infra`
的恢复流程也使用 kexec image + `disko-install`。

## 4. 对我们仓库的启发

如果以后要给 ARM 板或新主机批量装机，可以借鉴它的“ISO / kexec / netboot”
三态产物设计，而不是只维护一种安装介质。

## 5. 参考

- [nixos-images](https://github.com/nix-community/nixos-images)
