# linuxkit-nix 学习笔记

## 1. 是什么

`linuxkit-nix` 在 macOS 上用 LinuxKit 启动 Linux VM（HyperKit +
VPNKit，走 Hypervisor.framework 硬件加速），并自动配置成 Nix 远程
builder，让 Mac 可以构建 Linux 二进制。仓库已归档：README 明确
建议改用 nixpkgs 自带的 `darwin.builder`。134 star。

## 2. 组件

- `hyperkit` / `vpnkit` / `go-vpnkit` / `virtsock`：VM 和用户态网络
  底层；
- `linuxkit`：LinuxKit CLI；
- `linuxkit-builder`：核心，构建带 SSH + Nix 的 x86_64-linux VM
  镜像（stage-1/stage-2 init、kernel、runit 服务：sshd、acpid、
  vpnkit forwarder/port 暴露），并生成安装脚本；
- `nix-linuxkit-runner`：Rust 小工具，管理 hyperkit 进程和 pidfile、
  磁盘/内存/CPU 参数；
- `nix-script-store-plugin`：Nix store 插件。

## 3. 使用方式

安装后运行 `nix-linuxkit-configure`：

- 写 `~/.cache/nix-linuxkit-builder/` 状态目录；
- 配置 SSH（`/etc/nix/machines`、`~/.ssh/config`）；
- 安装 LaunchAgent `org.nix-community.linuxkit-builder.plist`；
- 之后 Nix 会把 `x86_64-linux` 构建任务 ssh 到 VM。

## 4. 为什么归档

- 2017 年 QEMU 还不支持 macOS Hypervisor.framework 硬件加速；
- 2018-2019 年 QEMU 支持稳定后，nixpkgs 的 `darwin.builder` 成为
  更好的方案，这个项目不再需要。

## 5. 对我们仓库的启发

- 我们构建在 ml-builder（Linux）上，Mac 只当客户端，不需要这套；
- 它说明“跨平台构建”的临时方案会被 nixpkgs 原生能力替代，优先
  看 nixpkgs 官方机制而不是维护独立组件。

## 6. 参考

- [linuxkit-nix](https://github.com/nix-community/linuxkit-nix)
- [nixpkgs darwin.builder](https://nixos.org/manual/nixpkgs/unstable/#sec-darwin-builder)
