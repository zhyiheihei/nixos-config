# go-nix 学习笔记

## 1. 是什么

`go-nix` 是用 Go 重写 Nix 核心组件的实验库，Apache-2.0，状态明确标注
experimental，当前 161 star。它提供 NAR、narinfo、derivation、store
path、hash、SQLite 和 wire protocol 等库，以及 `gonix` CLI。

## 2. 包结构

- `pkg/nar`：NAR 文件 Reader/Writer（接口类似 `archive/tar`），
  还有 `DumpPath` 把本地路径转成 NAR；
- `pkg/narinfo`：`.narinfo` 解析/生成，含签名（public/secret key）
  和 fingerprint；
- `pkg/derivation`：`.drv` 解析、derivation path 和 output hash
  计算；`store` 子包支持 map/filesystem/http/badger 多种存储；
- `pkg/nixbase32` / `pkg/nixhash`：Nix 特有的 base32 和 hash 编码；
- `pkg/storepath`：store path 解析和引用扫描；
- `pkg/sqlite`：用 sqlc 生成 binary-cache-v6、eval-cache-v5、
  fetcher-cache-v2、nix_v10 四种 Nix 数据库的查询代码；
- `pkg/wire`：Nix 底层 wire protocol 的读写；
- `cmd/gonix`：kong CLI，实现 `nar {cat,dump-path,ls}` 和 `drv`。

## 3. 工程

- flake 用 numtide/blueprint 组织，构建依赖 gomod2nix；
- `sqlc.yml` 管理 SQLite 代码生成；
- CI：`fixtures` job 用 Nix 2.12.1 重新生成 `test/testdata` 并
  `git diff --exit-code` 防漂移；`build` job 在 Go 1.20/1.21 和
  ubuntu/macos/windows 上跑 `go test -race -bench`；另有
  golangci-lint。

## 4. 与我们仓库的启发

- [gomod2nix](./gomod2nix.md) 的 NAR hash 计算就用到了
  `go-nix/pkg/nar`，说明这类库是 nix-community 内部互相复用的基础；
- 如果以后要在 zhyi-packages 里写 Go 工具处理 Nix store / NAR /
  binary cache，可以直接用这些包，而不是手写格式解析。

## 5. 参考

- [go-nix](https://github.com/nix-community/go-nix)
- [gomod2nix 学习笔记](./gomod2nix.md)
