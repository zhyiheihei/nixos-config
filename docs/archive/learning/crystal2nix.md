# crystal2nix 学习笔记

## 1. 是什么

`crystal2nix` 帮助把 Crystal 项目 nixify：读取 Shards 的
`shard.lock`，为每个依赖跑 `nix-prefetch-git`，生成 `shards.nix`
（url + rev + sha256 的 attrset），供 nixpkgs
`buildCrystalPackage { format = "shards"; lockFile; shardsFile; }`
使用。作者 Michael Fellinger / Peter Hoeg，19 star，MIT，Crystal
语言，2025-07 仍有维护。

```sh
nix-shell -p crystal2nix --run crystal2nix   # 生成 shards.nix
```

## 2. 实现（Crystal）

`src/` 结构清晰：

- `cli.cr`：OptionParser，参数 `--lock-file`（默认 shard.lock），
  文件不存在直接报错；
- `data.cr`：`ShardLock` / `Shard` 用 `YAML::Serializable` 解析
  v2 lock 格式（git + version）；
- `repo.cr`：URI normalize；rev 判定：version 形如
  `x.y.z+git.commit.<sha>` 时用 commit，否则 `v<version>`；
- `worker.cr`：对每个 shard 调
  `nix-prefetch-git --no-deepClone --url <url> --rev <rev>`，从 JSON
  输出取 sha256，写 `shards.nix`（属性名带引号，兼容名字里的点）；
- 支持任意 git 源（GitHub/GitLab/自建），不只 fetchFromGitHub。

## 3. 自举与 CI

- flake 用 nixpkgs 的 `crystal.buildCrystalPackage` 打包自己
  （`format = "shards"` + `shard.lock` + `shards.nix`）；
- devShell：crystal + shards + openssl + pkg-config；
- Makefile：`shard.lock` ← `shards install`，`shards.nix` ←
  二进制，`version.json` ← `shards version`；
- CI：`nix build .#crystal2nix` + `nix flake check`（spectator
  测试）。

## 4. 对我们仓库的启发

- 我们不构建 Crystal 项目，不引入；
- 它是“生态 lockfile → Nix fetcher 元数据”系列（cargo2nix、
  npmlock2nix、luarocks-nix 等）里的 Crystal 一员，模式一致；
- nixpkgs 侧用 `buildCrystalPackage` 消费 `shards.nix`，说明这类
  生成器最好只产出“数据”，构建逻辑留在 nixpkgs，职责最清晰。

## 5. 参考

- [crystal2nix](https://github.com/nix-community/crystal2nix)
