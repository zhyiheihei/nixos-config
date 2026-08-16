# nurl 学习笔记

## 1. 是什么

`nurl` 是一个 **从 URL 生成 Nix fetcher 调用** 的 Rust CLI
（MPL-2.0，768 star）：

```bash
$ nurl https://github.com/nix-community/patsh v0.2.0
fetchFromGitHub {
  owner = "nix-community";
  repo = "patsh";
  tag = "v0.2.0";
  hash = "sha256-...";
}
```

## 2. 支持的 fetcher

`fetchFromGitHub`、`fetchFromGitLab`、`fetchFromGitea`、
`fetchFromSourcehut`、`fetchCrate`、`fetchPypi`、
`builtins.fetchGit`、`fetchgit`、`fetchhg`、`fetchsvn`、
`fetchurl`、`fetchzip`、`fetchpatch` 等 18 种。默认从 URL 推断
fetcher，也可以用 `-f` 指定、`-F` 指定 fallback。

## 3. 常用参数

- `-S/--submodules`：是否抓 submodules；
- `-n/--nixpkgs`：指定 nixpkgs 路径（默认 `<nixpkgs>`）；
- `-i/--indent`：给生成的表达式加缩进（生成包时很有用）；
- `-H/--hash`：只输出 hash；
- `-j/--json` / `-p/--parse`：结构化输出；
- `-a/--arg`、`-A/--arg-str`：给 fetcher 传额外参数；
- `-o/--overwrite`：覆盖输出字段（例如把 `rev` 写成
  `v${version}`）；
- `-e/--expr`：不抓 URL，直接对 FOD 表达式求 hash。

## 4. 与 nix-prefetch 的区别

- nurl 自动推断 fetcher，nix-prefetch 要手选；
- nurl 尽量用非 FOD 的替代方式，避免每次都跑完整固定输出构建；
- nix-prefetch 更可配置、支持文件属性；
- nurl 针对“生成包表达式”场景提供了 indent / overwrite 等能力。

## 5. 与我们仓库的关系

- `nix-init` 的 hash 预取和 fetcher 生成就基于 nurl；
- 我们维护 `nvfetcher.toml` 时，遇到“手动写 fetch 表达式”的临时
  包可以用 nurl 快速生成；
- 版本更新时用 `--overwrite-rev-str 'v${version}'` 可以让输出直接
  进包表达式。

## 6. 参考

- [nurl](https://github.com/nix-community/nurl)
- [nix-init](../../human/learning/nix-init.md)
