# nix-init 学习笔记

## 1. 是什么

`nix-init` 是从 URL 生成 Nix 包骨架的 **Rust CLI**（MPL-2.0，
1446 star）。给一个仓库/发布页 URL，它会：

- 自动推断 fetcher 并预取 hash；
- 推断 Rust / Go / Python 依赖的 `cargoHash` / `vendorHash`；
- 交互式询问 pname、version、builder 等，带 fuzzy 补全；
- 检测 license；
- 生成格式化好的 Nix 表达式（可配置 nixfmt / alejandra）。

生成结果通常还要手动微调，README 明确提醒要复核 license 和
description。

## 2. 支持的 builder / fetcher

Builers：

- `stdenv.mkDerivation` / `stdenvNoCC.mkDerivation`；
- `buildRustPackage` / `buildGoModule` / `buildNpmPackage`；
- `buildPythonApplication` / `buildPythonPackage`。

Fetchers：

- `fetchFromGitHub` / `fetchFromGitLab` / `fetchFromGitea`；
- `fetchCrate` / `fetchPypi`；
- 以及 [nurl](./nurl.md) 支持的其他 fetcher。

## 3. 配置

`~/.config/nix-init/config.toml`：

```toml
maintainers = ["zhyiheihei"]
nixpkgs = "<nixpkgs>"
commit = true

[access-tokens]
github.com = "ghp_..."
```

支持 headless 模式（`--headless --url ...`）供 CI 使用，也支持
`--overwrite` 强制覆盖、`-C` 按 RFC 140 的 `pkgs/by-name` 目录提交。

## 4. 与我们仓库的关系

`nix-init` 非常适合 `zhyi-packages` 新包起步：

- 新包先 `nix-init -u <url>` 生成骨架；
- 再用 `nvfetcher.toml` 接版本源，避免手工维护 hash；
- 最后用 `nixpkgs-update` 验证更新、走反哺 nixpkgs 流程。

它和 nurl 是配套工具：nurl 生成 fetcher 表达式，nix-init 在其上
生成完整包。

## 5. 参考

- [nix-init](https://github.com/nix-community/nix-init)
- [nurl](./nurl.md)
