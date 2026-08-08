# nix-community 自运维与基础设施

## infra 仓库

`nix-community/infra` 是组织自己的 NixOS 配置仓库，包含：

- `hosts/build01-05`：x86_64 / aarch64 构建机；
- `hosts/darwin01/02`：Apple M4 darwin builder；
- `hosts/web01`：监控与网页服务；
- `terraform/`、`dnscontrol/`、`.sops.yaml`、`inv/` 等运维设施。

## CI 与缓存

- `buildbot-nix`：Nixbot，求值 `.#checks`，支持 fork PR 与 status badge；
- `hydra.nix-community.org`：Hydra 实例；
- `nix-community.cachix.org`：官方二进制缓存；
- `cache-nix-action`：GitHub Actions 里缓存 `/nix` store；
- `hydra-check`：查询 `hydra.nixos.org` 上某个包是否构建成功。

## 与我们的对照

我们使用 GitHub Actions + 私有 Attic（`attic.zhyi.xin/lantian`）。
组织使用自建 buildbot-nix + Cachix/Harmonia。两者解决的问题相同：
Nix 表达式构建 + 二进制缓存。
