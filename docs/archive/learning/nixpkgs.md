# nixpkgs（社区 fork）学习笔记

## 1. 是什么

`nix-community/nixpkgs` 是 NixOS/nixpkgs 的 fork（MIT，2 star）。
GitHub compare 显示：master **0 个领先提交**、落后上游 83 万+ 提交
（基本是 2023-05 的静态快照），没有任何实验改动。

## 2. 结论

- 这个仓库只是历史快照/占位 fork，没有独立内容；
- 我们以及所有部署都使用官方 NixOS/nixpkgs；
- 与 nix-community/nix（已学）一样，属于“同名 fork 无实质差异”
  的情况，记录即可。

## 3. 对我们仓库的启发

- 判断 fork 价值用 compare API 看 ahead/behind 提交数，比读
  代码更高效；
- 这类仓库不需要深入维护，也不需要引用。

## 4. 参考

- [nix-community/nixpkgs](https://github.com/nix-community/nixpkgs)
