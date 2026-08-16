# dream2nix-pypi-most-popular 学习笔记

## 1. 是什么

`dream2nix-pypi-most-popular` 是 DavHau 的 dream2nix 示例/测试仓库：
用 dream2nix 构建 PyPI 最热门的 500 个包（数据来自
hugovk/top-pypi-packages，2024-07 快照）。1 star，Nix，已归档；
HTML 报告发布在
[nix-community.github.io/dream2nix-pypi-most-popular](https://nix-community.github.io/dream2nix-pypi-most-popular/)
（buildbot.nix-community.org 的 CI 结果）。

## 2. flake 结构

- `500-most-popular-pypi-packages.txt`：`name==version` 列表；
- 每个包生成一个 dream2nix module：`pip.requirementsList =
  ["<name>==<version>"]`、`--no-binary`、lock 文件存
  `locks/<name>.<system>.json`；
- `skippedPackages` 记录跳过原因：dataclasses（stdlib）、scipy
  （f2py 锁定期失败）、pandas（numpy import 破坏锁定）、
  opencv-python（缺 build inputs）、great-expectations 等；
- `checks` 只收 `lock.isValid` 的包；`lockScripts` + `lock-all`
  app 用 nix-eval-jobs + parallel 批量补锁；
- `overrides.nix` 是可复用片段：withCC / useWheel / withLibCPP /
  withPkgConfig / withCMake / withMesonPy；
- `maturin.nix` 作为 local package set 支持 Rust 构建的 PyPI 包。

## 3. 对我们仓库的启发

- 我们不用 dream2nix，不引入；
- 它是“top-N 真实包做框架回归测试”的完整样例（同
  dream2nix-auto-test 思路，但针对 PyPI/pip）；
- `lockScripts + 批量补锁 + HTML 报告`的组织，对 zhyi-packages
  做包集健康度报告有参考价值。

## 4. 参考

- [dream2nix-pypi-most-popular](https://github.com/nix-community/dream2nix-pypi-most-popular)
