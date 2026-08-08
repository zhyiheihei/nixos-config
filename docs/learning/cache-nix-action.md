# cache-nix-action 学习笔记

## 1. 是什么

`cache-nix-action` 是 GitHub Action，用来把 Nix store（默认 `/nix`）
缓存到 GitHub Actions cache，加速 workflow。它是 `actions/cache` 的
fork 并针对 Nix 做了大量增强，MIT 协议，当前 167 star，主维护者
deemp。

## 2. 功能

- Linux/macOS 上恢复和保存 Nix store；
- 保存前用 `nix store gc --max ...` 收集垃圾，控制缓存体积；
- 按 key/前缀/创建时间/最近访问时间 purge 旧缓存；
- `restore-prefixes-all-matches` 合并多个 job 的缓存；
- 独立 `restore/` 和 `save/` action；
- 支持 `backend: buildjet` 和自定义
  `CUSTOM_ACTIONS_CACHE_URL` / `CUSTOM_ACTIONS_RESULTS_URL`；
- `saveFromGC.nix` 把依赖放进 profile，防止 GC 清掉 flake inputs。

## 3. Nix 数据库合并

恢复缓存时不只是解包文件，还要合并 Nix 数据库：

- 先 `checkpoint` 现有 SQLite WAL；
- 恢复 `/nix/var/nix/db/db.sqlite`，与现有数据库合并；
- 删除 `-wal` / `-shm` 文件；
- 要求 Nix 2.24+ 和 SQLite 3.37+。

## 4. CI（dogfood）

- `ci.yaml` / `buildjet-ci.yaml` 由 flake 里的 `nix/ci.nix` 生成；
- 自身 workflow 就用 cache-nix-action：构建 action、制造并合并
  “similar caches”、对比开/关缓存耗时、测试多种 Nix installer、
  测试旧 Nix 2.32.5、测试 store hash 冲突场景；
- flake 把 nixpkgs pin 到固定 commit，避免缓存漂移。

## 5. 对我们仓库的启发

- 我们 zhyi-packages 的 GitHub Actions 每次从零构建很慢，可以在
  `build.yml` 里加 cache-nix-action（primary-key 基于 flake.lock /
  nvfetcher 文件 hash，配合 `gc-max-store-size`），显著提速；
- “合并数据库 + checkpoint WAL”说明缓存 Nix store 不能只打包文件，
  必须同步处理 SQLite 状态；
- 它自己把 CI 从 flake 生成、并 dogfood 自己的 action，是很好的
  验证方式。

## 6. 参考

- [cache-nix-action](https://github.com/nix-community/cache-nix-action)
- [actions/cache](https://github.com/actions/cache)
