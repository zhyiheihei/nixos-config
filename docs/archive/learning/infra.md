# infra 学习笔记

## 1. 是什么

`nix-community/infra` 是 nix-community 组织的自运维仓库，包含所有
NixOS、NixBSD、nix-darwin、Terraform 和 DNSControl 配置，驱动
`nix-community.org` 及构建、CI、缓存等服务。175 star，是了解
nix-community 组织如何“自己吃自己的狗粮”的最佳入口。

## 2. 主机与角色

- `build01`（x86_64-linux）：社区构建机，带 riscv64 binfmt 模拟和
  FreeBSD NixBSD VM；
- `build02`（x86_64-linux）：`nixpkgs-update` bot（更新机器人 +
  supervisor）；
- `build03`（x86_64-linux）、`build04`/`build05`
  （aarch64-linux）：CI 构建机，支持 kvm/nixos-test；
- `darwin01`/`darwin02`（aarch64-darwin）：Apple Mac mini 构建机；
- `web01`（x86_64-linux，Gandi VPS）：nginx、nixbot、nur-update、
  quadlet 容器、rfc39、监控；
- `hosts/freebsd`：NixBSD 配置，作为 `x86_64-freebsd` remote
  builder。

## 3. 技术栈

- flake-parts + `lite-config` 管理 hosts；`srvos` 提供硬件 profile，
  `disko` 做 ZFS + systemd-boot 分区；
- `buildbot-nix`（pin 到维护者的 infra 分支）跑
  `buildbot.nix-community.org`，nixbot 跑 fork PR 的 CI；
- `nixpkgs-update` bot、`nur-update`、hercules-ci-effects 负责自动
  更新和部署；
- sops-nix 管 secrets，Terraform 管 GitHub repo 和 Hydra
  projects/jobsets，DNSControl 管 DNS；
- checks 覆盖每个 host 的 toplevel、NixOS tests、docs、
  terraform-validate、sops-check、dnscontrol-check。

## 4. 关键模块

- `modules/nixos/buildbot.nix`：buildbot master/worker，repo
  allowlist、sops secrets、Cachix push；
- `modules/nixos/hydra.nix`：hydra.nix-community.org，含日志清理、
  remote builders 配置；
- `modules/shared/ci-builder.nix`：匹配 nixbot 的
  max-silent-time/timeout；
- `modules/shared/community-builder.nix`、`remote-builder.nix`：
  社区构建机和远程构建授权。

## 5. 对我们仓库的启发

- 我们的 [infrastructure.md](infrastructure.md) 已概括组织自运维；
  这次看到的是实际代码形态；
- 我们自己的架构（ml-builder 远程构建 + GitHub Actions + sops）和
  它“builder + CI + secrets + DNS 全声明式”的思路一致，只是规模
  小很多；
- 值得借鉴：buildbot/nixbot 的 repo allowlist、nixpkgs-update
  supervisor、Terraform 管 GitHub 元数据、DNSControl 与 flake
  共用同一仓库。

## 6. 参考

- [nix-community/infra](https://github.com/nix-community/infra)
- [nix-community.org](https://nix-community.org)
