# travis-build（社区 fork）学习笔记

## 1. 是什么

`nix-community/travis-build` 是 [travis-ci/travis-build](https://github.com/travis-ci/travis-build)
的 fork（MIT，1 star）。描述写着“用于维护 nix builder”，但实际
对比显示：master **0 个领先提交**、落后上游 913 个提交，分支列表
里也没有 `nix` 相关分支——即只是一个 2019 年的静态快照，没有
落地任何改动。

## 2. 结论

- travis-build 是 Travis 生成构建脚本的 Ruby 工具，与我们无关；
- 这个 fork 没有独立内容，只是历史占位；
- 与 nix-community/nix、nixpkgs fork 同类，记录即可。

## 3. 对我们仓库的启发

- 判断“维护 fork”是否真有工作，仍以 compare API 的 ahead 提交和
  分支名为准；
- 这类仓库不需要引入或维护。

## 4. 参考

- [nix-community/travis-build](https://github.com/nix-community/travis-build)
