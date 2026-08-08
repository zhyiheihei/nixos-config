# yarn2nix 学习笔记

## 1. 是什么

`yarn2nix` 把 `yarn.lock` 转成 Nix 表达式（`yarn.nix`），再用
`mkYarnPackage` 离线安装依赖。仓库已归档：核心已并入 nixpkgs
（PR #108138）。GPL-3.0，作者 moretea，127 star。

## 2. 用法

```sh
yarn2nix > yarn.nix
```

```nix
mkYarnPackage {
  name = "front-end";
  src = ./.;
  packageJSON = ./package.json;
  yarnLock = ./yarn.lock;
  yarnNix = ./yarn.nix; # 省略时构建期动态生成
}
```

`yarn.nix` 是 `offline_cache`（linkFarm），内容是每个依赖的
`fetchurl`（从 resolved URL + sha1）或 `fetchgit`。

## 3. 实现

- 用 `@yarnpkg/lockfile` 解析 `yarn.lock`；
- 缺失 sha1 的条目先补 hash（`fixPkgAddMissingSha1`），若锁文件有
  变化默认 patch 并重写，`--no-patch` 则报错；
- git 依赖支持 `builtins.fetchGit` 或 `nix-prefetch-git`；
- 构建时用 yarn `--offline` 从离线缓存安装，避免网络依赖。

## 4. CI

- Travis（已随项目归档），`run-tests.sh` 分别用 IFD 开启/关闭跑
  测试。

## 5. 与我们仓库的启发

- 我们前端构建用 nixpkgs 原生 `fetchPnpmDeps` / `buildNpmPackage`，
  不需要 yarn2nix；
- nixpkgs 里 `mkYarnPackage` 仍沿用这条思路，属于历史参考。

## 6. 参考

- [yarn2nix](https://github.com/nix-community/yarn2nix)
- [语言生态打包概览](./language-packaging.md)
