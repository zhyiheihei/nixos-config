# pruned-racket-catalog 学习笔记

## 1. 是什么

`pruned-racket-catalog` 生成**精简版 Racket 包目录**（1 star，
Racket，2026-08 仍在维护）：从 `pkgs.racket-lang.org/pkgs-all`
出发，产出只含“外部包”的 catalog，供 Nix 侧（nixpkgs 的 Racket
打包）使用。

## 2. 精简逻辑（write-catalog.rkt）

- `reshape-dependencies`：丢掉依赖版本约束、只保留 default
  版本、删旧版本和时间戳字段；
- `keep-only-external-deps`：移除标着 `main-distribution` /
  `main-tests` 的捆绑包，并把它们从其余包依赖里剔除；
- 建**反向依赖图** + dummy 节点，DFS 找出“不可采纳”包（例如
  只有非 git 源或依赖缺失的包）并过滤；
- 自带一致性测试：保证剩余包的每个依赖要么是捆绑包、要么
  `racket`、要么在可采纳集合里；
- 输出：`pkgs-all`（完整 hash）、`pkgs`（名字列表）、
  `pkg/<name>`（每个包单独文件，即 Racket catalog 目录结构）。

## 3. CI

- `update.yml`：每月从 `catalog` 分支拉最新 `pkgs-all`，
  `nix run` 重新生成并自动提交 push；生成逻辑在 main，数据在
  `catalog` 分支。

## 4. 对我们仓库的启发

- 我们不打 Racket，不引入；
- 它和 all-cabal-json 同类：把生态 catalog 整理成 Nix 可消费的
  数据；“逻辑在 main、数据在专用分支”再次出现；
- “反向图 + DFS 找不可达包 + 不变式测试”是处理依赖图裁剪的
  干净做法。

## 5. 参考

- [pruned-racket-catalog](https://github.com/nix-community/pruned-racket-catalog)
