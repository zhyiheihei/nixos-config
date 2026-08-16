# flake.nix 学习笔记

## 1. 是什么

`flake.nix` 是 nix-community 里的**历史占位仓库**：描述写明“这里
是我们第一次讨论 flakes 的地方，此后活动已迁移到上游
NixOS/nix”。13 star，无 license，2018-11 后归档，仓库本身现在
是空的（源码 tar 里没有任何文件）。

## 2. 意义

- 它见证了 Nix flakes 从社区实验变成 Nix 官方特性的过程；
- 归档而非删除，保留了“flakes 讨论起点”的引用地址，避免链接
  失效；
- 实际内容早已进入 [NixOS/nix](https://github.com/NixOS/nix) 的
  flakes 实现和 RFC 0104。

## 3. 对我们仓库的启发

- 我们每天用 flake.lock，了解它的来源背景即可；
- “空仓库 + 说明性描述 + 归档”是保留历史引用锚点的低成本做法，
  值得在文档/链接迁移时借鉴。

## 4. 参考

- [flake.nix](https://github.com/nix-community/flake.nix)
