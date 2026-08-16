# nixos-apple-silicon 学习笔记

## 1. 是什么

`nixos-apple-silicon` 提供 Apple Silicon Mac 上裸机运行 NixOS 的包表达式和
NixOS 模块。安装后系统像普通 NixOS 一样配置和运维。

## 2. 依赖的上游工作

- Asahi Linux 的 `m1n1` bootloader/hypervisor；
- Asahi Linux 的 Linux 内核补丁；
- Mark Kettenis 的 U-Boot 移植；
- Alyssa Rosenzweig 的 Mesa GPU 驱动。

本项目目标是尽量复刻 Asahi Linux reference distro 的软件配置和版本，
大幅偏离的配置不会被接受。

## 3. 关键概念

- 通过 UEFI standalone 引导链安装；
- 提供二进制缓存；
- 提供 release notes 和维护指南；
- 包与模块基于 MIT 许可，但其中的 patches 和构建产物遵循各自许可证。

## 4. 对我们仓库的启发

我们目前没有 Apple Silicon 上的 NixOS 目标机，但组织基础设施里有
`darwin01/02`（Apple M4）做 darwin builder。这个仓库展示的是：

- 硬件移植仓库如何组织；
- 如何依赖上游（Asahi）而不是重复造轮子；
- 二进制缓存与安装文档如何配套。

## 5. 参考

- [nixos-apple-silicon](https://github.com/nix-community/nixos-apple-silicon)
- [UEFI standalone guide](https://github.com/nix-community/nixos-apple-silicon/blob/main/docs/uefi-standalone.md)
