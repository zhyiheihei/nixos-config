# nix-unit 学习笔记

## 1. 是什么

`nix-unit` 是 Nix 代码的单元测试运行器，直接用 Nix evaluator 的
C++ API 求值，而不是起外部进程。GPL-3.0，作者 adisbladis，135 star，
版本号跟随 Nix（当前 2.35.1）。

## 2. 特点

- 测试结构兼容 `lib.debug.runTests`：attrset 里每个测试是
  `{ expr; expected; }`；
- 单个属性可以独立失败，即使整个测试集里有求值错误也能逐个报；
- 并行 worker、`--max-failures`、`--flake`、`--show-trace`、
  `--quiet` 等选项；
- 失败时用 difftastic 显示 diff；
- 附带 `lib.coverage.addCoverage`，为公共接口生成覆盖测试。

## 3. 实现

- C++23 + meson，链接 nixpkgs 的 nixComponents（nix-main/store/
  expr/cmd/flake），用 Nix C++ API 内嵌求值；
- 错误类型按 Nix 内部异常映射成测试结果（RestrictedPathError、
  TypeError、AssertionError 等）；
- 支持 flake 和普通表达式两种入口。

## 4. 工程与 CI

- flake 提供 nix-unit/doc 包、devShell、`modules.flake`
  （flake-parts module，支持 `nix flake check`）和 flake-parts 模板；
- CI 用 [nix-github-actions](nix-github-actions.md) 生成矩阵，
  另跑 `tests/tests.py`；依赖更新自动合并；
- 与 Lix 不兼容，社区 fork 出 lix-unit 分别维护。

## 5. 与 namaka 对比

- nix-unit：能测求值失败、不依赖快照；
- [namaka](namaka.md)：快照测试、不能测求值失败；
- 两者互补，namaka 适合行为回归，nix-unit 适合精确断言。

## 6. 对我们仓库的启发

- 我们 `helpers/` 里如果有纯 Nix 函数，可以用 nix-unit 做精确断言，
  namaka 做快照，比手写 runTests 更好维护。

## 7. 参考

- [nix-unit](https://github.com/nix-community/nix-unit)
- [nix-unit docs](https://nix-community.github.io/nix-unit/)
- [Unit test your Nix code (Tweag)](https://www.tweag.io/blog/2022-09-01-unit-test-your-nix-code/)
