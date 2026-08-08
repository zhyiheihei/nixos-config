# npmlock2nix 学习笔记

## 1. 是什么

`npmlock2nix` 是纯 Nix 库：解析 `package.json` + `package-lock.json`，
提供 `shell`、`node_modules`、`build` 三种输出。Apache-2.0，源自
Tweag，148 star。特点：不生成代码、restricted evaluation 可用、
支持 GitHub 依赖、有单元和集成测试。

## 2. v1 / v2

- npm < 7 的 lockfile v1 走 `npmlock2nix.v1`；
- npm >= 7 的 lockfile v2 走 `npmlock2nix.v2`（v2 仍是 beta API）；
- 不带前缀调用会 fallback 到 v1 并打迁移警告。

## 3. 主要函数

```nix
npmlock2nix.shell { src = ./.; }                    # node_modules 开发环境
npmlock2nix.node_modules { src = ./.; }             # 等价 npm install 的 derivation
npmlock2nix.build {
  src = ./.;                                        # 打包任意 npm 项目
  buildCommands = [ "npm run build" ];
  installPhase = "cp -r dist $out";
}
```

关键参数：

- `node_modules_mode`：copy 或 symlink；
- `node_modules_attrs`：透传给 `node_modules`；
- `githubSourceHashMap`：受限求值时给 GitHub 依赖提供 rev/hash；
- `sourceOverrides`：对依赖源码做 patch；
- v1 还有 `preInstallLinks`，v2 用 `sourceOverrides` 替代。

## 4. 实现

- 从 lockfile 读每个依赖的 `resolved` URL 和 `integrity` hash，
  用 `fetchurl` 拉取；
- GitHub 引用解析成 owner/repo/rev，restricted 模式用
  `fetchFromGitHub`；
- 提供 `fetchGitWrapped` 兼容 Nix 2.3/2.4；
- 测试：单元测试用 `lib.debug.runTests`，集成测试用 smoke，
  `test.sh` 一起跑；CI 同时在 Nix 2.3 和最新稳定版上执行。

## 5. 与我们仓库的启发

- 我们 [language-packaging.md](./language-packaging.md) 已决定 npm/pnpm
  走 nixpkgs 原生 `fetchNpmDeps` / `fetchPnpmDeps`，npmlock2nix 属于
  更早的 nix-community 路线，不需要迁移；
- 它“纯 Nix 解析 lockfile + 单元/集成双测试”的组织方式仍值得参考。

## 6. 参考

- [npmlock2nix](https://github.com/nix-community/npmlock2nix)
- [语言生态打包概览](./language-packaging.md)
