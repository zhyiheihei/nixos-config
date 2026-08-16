# nixpkgs-swh 学习笔记

## 1. 是什么

`nixpkgs-swh` 生成 nixpkgs 构建所需全部 tarball 的
`sources.json`，交给 [Software Heritage](https://www.softwareheritage.org/)
归档，保证 nixpkgs 的源码不会被上游删档。维护者 nlewo，39 star，
MIT。每天由 Buildkite CI 选一个 Hydra 已构建的 nixpkgs commit 生成，
产物发布在 [nixpkgs-swh.nixos.org](https://nixpkgs-swh.nixos.org)
（sources-unstable.json + 分析 README）。

## 2. 生成管线

`nix run .#nixpkgs-swh-generate -- [--testing] OUT unstable`，
四个脚本分工：

1. **generate.sh**：先查 Hydra jobset
   （`nixos/trunk-combined` 或 `release-*`）的 `latest-eval`，拿到
   nixpkgs commit 和 eval id；再
   `nix-instantiate -I nixpkgs=<commit>.tar.gz --strict --eval`
   swh-urls.nix（`GC_INITIAL_HEAP_SIZE=4g`，全量评估内存压力大）；
2. **swh-urls.nix**：import nixpkgs 的 `all-tarballs.nix`，调
   find-tarballs.nix 收集所有 fetchurl/fetchgit/fetchhg/fetchsvn
   依赖，把 `mirror:` URL 用 nixpkgs mirrors.nix 解析成真实 URL，
   hash 统一转 SRI；
3. **post-process.py**：按 store path 去重、拆分 SRI hash、给
   git/hg/svn 源补 `*_url` / `*_rev` 字段、删空字段，并用
   aiohttp + uvloop 并发向 `cache.nixos.org` 拉每个源的
   `.narinfo`（供 SWH nixguix lister 使用）；
4. **analyze.py**：正则把 URL 分类（github archive/release、
   hackage、crates、rubygems、gitlab、bitbucket…）和文件类型
   （tar.gz/zip/jar/deb/patch…），输出按 host/scheme/type 统计的
   README。

`find-tarballs.nix` 的关键技巧：用 `genericClosure` 走完整依赖图，
`tryEval` 跳过求值失败的节点，只收 `outputHash` + `url/urls` 的
fetch 型 derivation，并保留 `rev`、`fetchSubmodules`、
`sparseCheckout`、`postFetch` 等 SWH 需要的字段。

## 3. Flake / NixOS / CI

- flake 提供 overlay + `nixpkgs-swh-generate` 包；
- `nixosModules.nixpkgs-swh`：`services.nixpkgs-swh` 选项
  （enable/testing/outputDir），systemd timer 每天跑
  `generate unstable`；
- GitHub Actions 只做冒烟测试：每天 `--testing` 模式生成
  `nixpkgs.hello` 的 sources.json 并 `jq` 展示；
- 全量发布走 `publish.sh`（Buildkite）：生成后 init 一个临时 git
  仓库，force-push 到本仓库 `gh-pages` 分支，`sources-unstable.json`
  和 README 由 Pages 托管。

## 4. 对我们仓库的启发

- 我们不做源码归档，不引入；
- “遍历 derivation 图收集 fetcher 信息”对审计依赖来源、生成 SBOM
  或构建缓存报告很有用，`genericClosure` + `tryEval` 是标准写法；
- 每天“跟着 Hydra 最新 eval 生成一份外部可见数据”的定时任务，
  和我们 nvfetcher/更新类工作流的定位类似，只是消费方不同。

## 5. 参考

- [nixpkgs-swh](https://github.com/nix-community/nixpkgs-swh)
- [Software Heritage](https://www.softwareheritage.org/)
