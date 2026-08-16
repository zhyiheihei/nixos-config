# rnix-hashes 学习笔记

## 1. 是什么

`rnix-hashes` 是 zimbatm / NumTide 的 Rust 小工具（作者 Andika
Demas Riyandi）：在 Nix 哈希的不同编码之间互转。MIT，10 star，
2021-01 已归档——现在这个功能由 `nix hash convert` 内置实现。

```sh
$ rnix-hashes sha256-Y39OVtscIh6VSH4WBwCDM/eGPFEOxzXtgnHU708CnqU=
SRI     sha256-Y39OVtscIh6VSH4WBwCDM/eGPFEOxzXtgnHU708CnqU=
base16  637f4e56db1c221e95487e1607008333f7863c510ec735ed8271d4ef4f029ea5
base32  19cy097yzm3ihbnkbiqfa4y8dxrkhc00f5ky92aiw8hwvdb4wzv3
base64  Y39OVtscIh6VSH4WBwCDM/eGPFEOxzXtgnHU708CnqU=
```

## 2. 实现

- `src/main.rs`：clap 2 CLI，输入一个 hash，可选 `--encoding`
  （BASE16 / BASE32 / BASE64 / PBASE16 / PBASE32 / PBASE64 / SRI），
  不指定就打印全部格式（含 padded 变体）；
- `src/base32.rs`：Nix base32 字母表编解码；
- `src/hash.rs`：hash 类型与编码解析；
- 打包走 naersk，flake 提供 `rhashes` overlay 和 devShell；
- CI：nix-shell 里 `cargo build`，产物推 numtide cachix。

## 3. 对我们仓库的启发

- 我们用 `nix hash convert` / `nix-prefetch-url` 就够了，不需要
  引入；
- 它说明这类“一次性问题小工具”生命周期短：Nix 官方补上内置
  功能后就归档，我们遇到类似需求时优先查 `nix <subcommand>
  --help`，再考虑写工具。

## 4. 参考

- [rnix-hashes](https://github.com/nix-community/rnix-hashes)
