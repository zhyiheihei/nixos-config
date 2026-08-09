# srvos 学习笔记

## 1. 是什么

`srvos`（Numtide 维护，MIT，994 star，状态 stable）是 **NixOS
服务器配置“口味”模块集合**：把 Numtide 在多套部署里反复写的东西
沉淀成可直接 import 的 NixOS / nix-darwin module。

它不是通用框架，而是按“垂直领域”优化：NixOS server、常见云厂商
硬件、GitHub Actions runner、Nix remote builder 等。

## 2. 模块分类

`nixos/` 下按四层组织：

- `common/`：所有 server 都该有的基线（nix、openssh、sudo、
  networking、serial、update-diff、zfs）；
- `server/`：server profile 的汇总入口；
- `hardware-*`：具体硬件/云厂商 profile（例如 Hetzner AMD）；
- `mixins/`：可组合片段（terminfo、mdns、nginx、systemd-boot、
  latest-zfs-kernel、cloud-init、tracing、telegraf、trusted-nix-caches）；
- `roles/`：完整角色（github-actions-runner、nix-remote-builder）。

`darwin/` 有对应的 common / server / desktop / mixins 子集；
`shared/` 放跨系统共享的模块。

## 3. 使用示例

```nix
modules = [
  srvos.nixosModules.server
  srvos.nixosModules.hardware-hetzner-amd
  srvos.nixosModules.mixins-terminfo
  srvos.nixosModules.roles-github-actions-runner
];
```

## 4. 与我们仓库的关系

我们仓库的 `nixos/server.nix` / `server-components/` 承担了类似
职责，但跟随作者 xddxdd 的体系，不能直接替换为 srvos：

- 参考价值在“公共基线 + 硬件片段 + 角色 + mixin”的分层：我们
  的 `minimal-*` / `server-*` / `client-*` 就是这个思路的更大版；
- `update-diff` 这类“切换前先展示差异”的模块我们可能也想补；
- srvos 的 hardware profile 可以启发我们整理
  `nixos/hardware/` 片段。

## 5. 参考

- [srvos](https://github.com/nix-community/srvos)
- [srvos 文档](https://nix-community.github.io/srvos/)
