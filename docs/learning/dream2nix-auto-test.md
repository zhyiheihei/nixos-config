# dream2nix-auto-test 学习笔记

## 1. 是什么

`dream2nix-auto-test`（nix-community fork，源 DavHau）是 dream2nix
的自动测试仓库：用 dream2nix 自动生成各生态“最热门 N 个包”的
package set，每套一个分支，每天由 bot 更新，Hercules CI 暴露哪些
包构建失败。MIT，3 star，Nix。

## 2. 结构与生成

- `indexes.json` 定义索引：
  - `pkgs-haskell`：libraries-io 按 dependent_repos_count 取 500；
  - `pkgs-nodejs`：npm 500；
  - `pkgs-rust`：crates-io 按 downloads 取 500（builder=crane）；
- `flake.nix`：`dream2nix.lib.makeFlakeOutputsForIndexes` 按索引
  生成包集；`packageOverrides` 把所有包 `buildScript = ":"`
  （只验证索引/translate/lock，不全量编译）；`checks = packages`。

## 3. CI

- `generate-packages.yml`：每天对每个索引：更新 dream2nix input →
  `nix run .#ci-job-<name>` → push 对应 `pkgs-*` 分支；
- `gh-pages.yml`：每 10 分钟把结果页推到 gh-pages；
- 构建状态看各分支的 Hercules CI。

## 4. 对我们仓库的启发

- 它和 dreampkgs（已学）互补：dreampkgs 是精选包集，这里是“热门
  包自动化回归测试”；
- “生态 top-N + 每天重生成 + 分分支跑 CI”是给打包框架做持续
  回归的轻量方案，若 zhyi-packages 想评估“我的打包 helper 是否
  健壮”可照此组织。

## 5. 参考

- [dream2nix-auto-test](https://github.com/nix-community/dream2nix-auto-test)
