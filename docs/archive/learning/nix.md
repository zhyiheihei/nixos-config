# nix（社区 fork）学习笔记

## 1. 是什么

`nix-community/nix` 是 NixOS/nix 的“社区实验 fork”（LGPL-2.1，
6 star，C++）。GitHub 描述明确：**“Community fork to try things
out. Not official!”**，即非官方实验场，不是我们要用的 Nix。

## 2. 与上游的差异

用 GitHub compare API 检查（master 对 NixOS/nix:master）：

- 落后上游 1.2 万+ 提交（基本停在 2022 年的快照）；
- 只有 4 个领先提交，全是 dependabot 的 GitHub Actions 依赖
  升级（checkout v2→v3、install-nix-action 16→17 等）；
- README 就是上游 README，没有实验性功能改动。

## 3. 对我们仓库的启发

- 我们用官方 NixOS/nix（及 Lix 生态），不会引用这个 fork；
- 它提醒我们：org 里名称相同的 fork 未必有意义，判断仓库价值
  要看“相对上游领先/落后的提交”，而不是名字；
- 遇到这类仓库，直接记录“过期实验 fork、无独立内容”即可，不用
  深入读源码。

## 4. 参考

- [nix-community/nix](https://github.com/nix-community/nix)
- [NixOS/nix（官方）](https://github.com/NixOS/nix)
