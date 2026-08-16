# nixos-anywhere 学习笔记

## 1. 是什么

`nixos-anywhere`（Numtide 维护，MIT，3350 star）是一条命令完成
**通过 SSH 远程安装 NixOS** 的工具。目标机只要能被 SSH 访问且
运行 x86_64 Linux（有 kexec），就可以无值守装机：

```bash
nix run github:nix-community/nixos-anywhere -- \
  --flake .#myHost root@target.example.com
```

内部流程：

1. 用 `get-facts.sh` 探测目标机（OS、架构、是否 NixOS、是否
   installer、root 权限、容器、IPv6、可用工具）；
2. 目标机不是 NixOS installer 时，通过 kexec 引导临时 NixOS
   installer 内核；
3. 用 [disko](disko.md) 按声明分区/格式化；
4. 把 flake 里的 NixOS configuration 复制进去并 `nixos-install`；
5. 可选：额外安装包、拷贝文件、执行 post-install 命令。

## 2. 源码结构

仓库很小，核心只有两个 shell 脚本：

- `src/get-facts.sh`：目标机探测；
- `src/nixos-anywhere.sh`：编排 SSH + kexec + disko +
  nixos-install 全过程。

flake 输入 pin 了 disko、nixos-images（installer 镜像）、
nix-vm-test（测试）和 treefmt-nix；`packages.nixos-anywhere` 是主
程序，`devShells.terraform` 提供 Terraform provider 开发环境。

## 3. 典型用法与限制

- `--kexec <url>`：自定义 kexec 镜像，可支持 aarch64 等非 x86_64
  目标；
- `--no-reboot` / `--phases`：分阶段执行，适合调试；
- `--extra-files <dir>`：安装后额外拷贝文件（例如 secrets）；
- 目标机必须有 root 权限；不支持 Wi-Fi，网络必须是可达的
  LAN/VPN/公网；
- **不能对生产服务器运行**：会清空整个磁盘。

## 4. 测试

仓库用 nix-vm-test 写了一套真实 VM 测试：

- 从 NixOS 目标机安装；
- 从 `nixos-generate-config` 输出安装；
- 分离 phases / sudo / 远程构建；
- Linux kexec 场景。

CI 在 x86_64-linux 跑这些测试，保证主流程不漂移。

## 5. 对我们仓库的启发

我们文档里“新主机接入先 SSH host key + SOPS，再进 hosts/”的流程，
正好是 nixos-anywhere 的适用场景；未来如果要从装好 Linux 的 VPS
或二手服务器接入 NixOS，可以直接复用：

- 新主机 `host.nix` / `configuration.nix` 写好后再跑
  `nixos-anywhere --flake .#<host>`；
- 磁盘布局由 disko 声明，避免手工 fdisk；
- secrets 用 `--extra-files` + SOPS 解密后的目录注入。

## 6. 参考

- [nixos-anywhere](https://github.com/nix-community/nixos-anywhere)
- [nixos-anywhere 文档](https://nixos-anywhere.org/)
- [disko](disko.md)
