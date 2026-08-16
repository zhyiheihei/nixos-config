# nixpkgs.lib 学习笔记

## 1. 是什么

`nixpkgs.lib` 是 nixpkgs `lib` 的“廉价、持续 rebase”镜像仓库：只保留
`lib/` 目录，让你不用加载整个 nixpkgs 就能用 `lib` 函数。MIT（沿用
nixpkgs 版权），108 star。

## 2. 内容

- 就是 nixpkgs `lib/` 的逐文件镜像：trivial、fixedPoints、
  attrsets、lists、strings、modules、options、types、licenses、
  systems、cli、generators、path/fileset、flakes 等；
- `lib/default.nix` 保持 nixpkgs 原版结构（`makeExtensible'` +
  `callLibs`），可以 `extend`；
- flake 入口只是转发到 `lib/flake.nix`。

## 3. 更新机制

- `update.yml` 每周运行：
  - bare clone nixpkgs；
  - `git-filter-repo --path lib --path COPYING` 只保留 lib；
  - 把过滤后的 master 用 `-X theirs` 合并进本仓库；
- 因此它始终接近 nixpkgs-unstable 的 lib。

## 4. 对我们仓库的启发

- 我们代码里 `lib` 都来自 nixpkgs，日常不需要单独引它；
- 如果以后写“不依赖完整 nixpkgs 的轻量工具/求值”，可以用它省掉
  大量求值成本；
- “持续 rebase + filter-repo 子集镜像”的维护模式也值得借鉴。

## 5. 参考

- [nixpkgs.lib](https://github.com/nix-community/nixpkgs.lib)
- [nixpkgs lib](https://github.com/NixOS/nixpkgs/tree/master/lib)
