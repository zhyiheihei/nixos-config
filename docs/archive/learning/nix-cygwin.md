# nix-cygwin 学习笔记

## 1. 是什么

`nix-cygwin` 是 NixOS/nixpkgs 的实验 fork：给 nixpkgs 加 Cygwin
支持。MIT，3 star，无独立 README。仓库默认 `master` 落后上游
15 万+ 提交且无领先提交；实验内容在 **`cygwin-stdenv`** /
`cygwin-test` 分支上（cygwin-stdenv 领先上游 137 个提交）。

## 2. cygwin-stdenv 分支内容

提交历史（从早到晚）显示完整实验路径：

- `HACK: add cygwin system`：先给 nixpkgs 系统列表塞进
  `x86_64-cygwin` 等；
- `stdenv/cygwin: init cross-based stdenv`：基于交叉编译初始化
  Cygwin stdenv；
- `bintools-wrapper` / `ld-wrapper`：处理 Cygwin PE 的
  `--high-entropy-va`、hardening 兼容；
- `deterministic-uname`：uname 支持 Cygwin；
- `gcc: enable threads on cygwin`、`newlib-cygwin` 修复；
- 大量“fix cygwin build”逐包补丁：bash、zstd、libxml2、git、
  vim、icu、meson、ninja、cpython 等；
- `HACK: check-cygwin` 脚本 + 多处 `HACK: undo changes causing
  rebuilds`（试验期为了快速迭代故意撤销重构建）。

整体停留在 2022 年前后的 nixpkgs 快照上，属于历史实验，未进
上游。

## 3. 对我们仓库的启发

- 我们不构建 Windows/Cygwin，不引入；
- 它展示了“给大型包集加新平台”的 fork 工作流：先 system +
  stdenv 骨架，再逐包修，配合临时 HACK 脚本做冒烟；
- 判断此类 fork 时优先看非默认分支的领先提交，而不是默认
  master。

## 4. 参考

- [nix-cygwin](https://github.com/nix-community/nix-cygwin)
