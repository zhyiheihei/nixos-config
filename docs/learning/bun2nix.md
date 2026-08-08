# bun2nix 学习笔记

## 1. 是什么

`bun2nix` 是 Rust 写的工具，把 Bun v1.2+ 的 `bun.lock` 转成 Nix
表达式（`bun.nix`），并提供 Nix 函数在可复现 derivation 中消费这些
依赖。MIT 协议，主维护者 baileylu，157 star。

## 2. 组成部分

- `programs/bun2nix`：Rust CLI，解析 lockfile、prefetch 依赖、生成
  Nix 表达式（`bun.nix`）；
- `programs/cache-entry-creator`：Zig 程序，用 wyhash 复刻 Bun
  全局缓存条目格式；
- `nix/fetch-bun-deps.nix`：把依赖源码做成 symlink farm，模拟
  bun 的缓存目录；支持从 `bunfig.toml` / `.npmrc` 解析 registry
  token，给 `fetchurl` 加认证头；
- `nix/mk-derivation.nix`：Bun 构建 hook（`resolve-catalog.ts` 处理
  catalog/workspace）；
- `nix/write-bun-application.nix` / `write-bun-script-bin.nix`：
  两种打包入口；
- `templates/`：catalog（workspace monorepo）和应用模板。

## 3. 工程与 CI

- flake-parts 组织，递归导入 `nix/` 下所有 `.nix` 文件；
- 文档用 mdbook（`docs/`），treefmt 格式化；
- CI 主体是 nix-community 的 Hercules CI（`nix flake check`）；
- GitHub Actions：`gh-pages.yml` 部署文档，`npm-packages-publish.yml`
  发布 `bun2nix-js` 到 npm。

## 4. 与我们仓库的启发

- 我们目前的前端依赖走 nixpkgs 原生 `fetchPnpmDeps` +
  `pnpmConfigHook`，没有 Bun 项目，不需要引入；
- 如果以后 zhyi-packages 要加 Bun 包，bun2nix 是现成路线，且它
  “生成表达式 + Nix 侧消费 hook”的分层和我们的
  [language-packaging.md](./language-packaging.md) 思路一致；
- registry 认证注入（bunfig/.npmrc → curl header）值得借鉴，私库
  场景很实用。

## 5. 参考

- [bun2nix](https://github.com/nix-community/bun2nix)
- [bun2nix docs](https://nix-community.github.io/bun2nix/)
- [Bun](https://bun.sh)
