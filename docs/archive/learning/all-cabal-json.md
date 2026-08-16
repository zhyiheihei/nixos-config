# all-cabal-json 学习笔记

## 1. 是什么

`all-cabal-json` 是 DavHau 维护的数据仓库：把 Hackage 上所有公开
Haskell 包的 `.cabal` 文件转成 JSON（并附带 hashes/cabal 副本），
供 dream2nix 等工具使用。MIT，3 star，Nix，2023-12 后停更。仓库
约 209MB，数据在 `hackage` 分支，main 分支只放生成逻辑。

## 2. 生成管线

`flake.nix`：

- 输入：nixpkgs、`commercialhaskell/all-cabal-hashes`（非 flake）、
  NorfairKing 的 `cabal2json`、flake-utils；
- `converter` 脚本：对每个 cabal 文件跑 `cabal2json | jq .` 写
  JSON，同时复制同名 `.hashes.json` 和 `.cabal`；
- `updater`：`find . -name '*.cabal'` + `parallel` 全量转换；
- overlay 里把 cabal2json 及其依赖（autodocodec）patch 到
  ghc8107 的 haskellPackages。

## 3. CI

`update.yml`：每天 03:00（或手动）checkout `hackage` 分支，跑
`nix run ... --update-input all-cabal-hashes`，提交并 push，自动
同步最新 Hackage 元数据。

## 4. 对我们仓库的启发

- 我们不构建 Haskell，不引入；
- 它是“把生态元数据全量转成结构化 JSON 供工具消费”的典型数据
  仓库（和 nixpkgs-swh 的 sources.json、nur 的 packages.json
  同类）；数据放独立分支、逻辑放 main 是省空间的做法；
- dream2nix 生态的 Haskell 支持依赖这类数据，理解了它就能理解
  dream2nix 的 Haskell 模块来源。

## 5. 参考

- [all-cabal-json](https://github.com/nix-community/all-cabal-json)
