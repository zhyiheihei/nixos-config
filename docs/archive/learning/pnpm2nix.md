# pnpm2nix 学习笔记

## 1. 是什么

`pnpm2nix` 是纯 Nix 实现的 `pnpm-lock.yaml` 转换器，提供
`mkPnpmPackage` / `mkPnpmEnv`。MIT 协议，97 star。

**状态：不再维护**，只兼容 lockfile v5.0 及以下（当前 pnpm 已是
v9+）；支持 pnpm 10 的维护分支是
[FliegendeWurst/pnpm2nix-nzbr](https://github.com/FliegendeWurst/pnpm2nix-nzbr)。

## 2. 用法

```nix
mkPnpmPackage {
  src = ./.;
  # packageJSON = ./package.json;
  # pnpmLock = ./pnpm-lock.yaml;
}
```

开发环境用 `mkPnpmEnv (import ./default.nix)`。

## 3. 实现

- 用 `yaml2json` + `jq` 把 pnpm-lock.yaml 转 JSON；
- `pnpmlock.nix` 把锁文件图改写成 DAG：解析 peer/dependencies 为
  绝对 attr 名、注入 name/version、打破循环依赖；
- `semver.nix` 实现版本满足判断；
- `derivation.nix` 从 registry tarball（`integrity` hash）fetch
  每个包，构建 `node_modules`；`link:` 本地包拆成子 derivation；
- `allowImpure` 处理 pnpm 没给 checksum 的 GitHub 依赖。

## 4. 测试

- `tests/` 覆盖 lolcatjs、sharp（native）、web3（-beta）、peer
  deps、循环依赖、scoped、file deps、workspace link 等；
- Travis 跑 `make test`（`nix-build tests/default.nix`）。

## 5. 与我们仓库的启发

- 我们 [language-packaging.md](language-packaging.md) 走 nixpkgs
  原生 `fetchPnpmDeps` + `pnpmConfigHook`，不需要 pnpm2nix；
- 它展示了纯 Nix 解析锁文件和处理依赖图/循环的复杂细节，是历史
  参考；维护分支只用于特定版本兼容需求。

## 6. 参考

- [pnpm2nix](https://github.com/nix-community/pnpm2nix)
- [pnpm2nix-nzbr（维护 fork）](https://github.com/FliegendeWurst/pnpm2nix-nzbr)
