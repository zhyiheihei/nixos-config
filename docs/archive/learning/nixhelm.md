# nixhelm 学习笔记

## 1. 是什么

`nixhelm` 是 Helm charts 的 Nix 化集合：把 chart 的版本和 hash 固定
在 `charts/` 里，使 chart 成为普通 Nix 输入。Apache-2.0，作者
farcaller，152 star，当前收录 81 个 chart 仓库。

## 2. 工作原理

- `charts/<repo>/<chart>/default.nix` 存版本和源 hash；
- flake 用 haumea 加载 `charts/`，输出：
  - `chartsMetadata`：chart 元数据；
  - `chartsDerivations.<system>.<repo>.<chart>`：下载 chart 的
    derivation；
  - `charts { pkgs = ... }`：不依赖固定 nixpkgs 的快捷入口；
- 渲染成 Kubernetes manifests 由
  [nix-kube-generators](https://github.com/farcaller/nix-kube-generators)
  的 `buildHelmChart` 在构建期完成，nixhelm 只负责提供 chart；
- 每晚自动刷新，更新以 commit 形式出现。

## 3. helmupdater

- Python CLI（uv2nix + pyproject-nix 构建），支持 HTTP/HTTPS chart
  repo 和 OCI registry；
- 版本解析用 `packaging`，跳过 prerelease，只选最新稳定版；
  当前版本被 yank 时会降级；
- 命令：`init`（新增 chart 并提交）、`update` / `update-all`、
  `build`（构建 derivation）、`rehash`；
- 支持 registry 认证和 e2e 测试（本地 HTTP/OCI registry +
  oauth2-server）。

## 4. CI

- `update-charts.yml`：每天自动 `update-all --commit` 并 push；
- `update-chart.yml`：手动更新单个 chart；
- `rebuild-cache.yml`：`update-all --commit --build` 并推 Cachix；
- `cache-updated.yml`：push 后只重建变更的 chart 并更新缓存。

## 5. 与我们仓库的启发

- 我们用 podman 容器，不跑 Kubernetes/Helm，暂时用不上；
- 它的“外部产物版本/hash 固定 + 每晚自动更新 + Cachix 缓存”和
  zhyi-packages 的 nvfetcher + update workflow 思路一致；
- flake 用 uv2nix 构建 Python 工具，和 authentik-nix 一样，印证
  我们语言打包笔记里“uv2nix 是当前路线”的判断。

## 6. 参考

- [nixhelm](https://github.com/nix-community/nixhelm)
- [nix-kube-generators](https://github.com/farcaller/nix-kube-generators)
- [Helm](https://helm.sh)
