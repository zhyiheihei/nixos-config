# nix4vscode 学习笔记

## 1. 是什么

`nix4vscode` 是 VSCode 的 Nix overlay，同时支持 VSCode Marketplace 和
OpenVSX。用 Rust exporter 预取扩展元数据和 hash，数据提交在仓库里。
Apache-2.0，134 star。

## 2. 用法

```nix
pkgs = import nixpkgs {
  config.allowUnfree = true;
  overlays = [ nix4vscode.overlays.default ];
};

extensions = pkgs.nix4vscode.forVscode [
  "tamasfe.even-better-toml"
  "editorconfig.editorconfig.0.9.4" # 指定版本
];
```

函数族：

- `forVscode` / `forVscodeVersion` / `forVscodePrerelease` /
  `forVscodeVersionPrerelease`；
- `forOpenVsx` 系列（OpenVSX registry）；
- `forVscodeExt decorators` / `forOpenVsxExt decorators`：带自定义
  decorator（patch/buildInputs 等）。

decorator 优先级：外部传入 > 包 override > 仓库自带
`nix/decorators/`。

## 3. 实现

- Rust workspace：`crates/code_api`（Marketplace API 客户端）+
  `crates/exporter`（抓取扩展信息、计算 hash，写 SQLite 和
  `data/vscode` / `data/openvsx` JSON）；
- `nix/forVscodeVersionRaw.nix` 把扩展列表解析成
  `fetchurl` + `unpack-vsix-setup-hook` 的 derivation；
- `data/` 提交扩展元数据，使构建不依赖实时网络。

## 4. CI

- `export-vscode.yml` / `export-openvsx.yml`：每天运行 exporter，
  更新 `data/` 并提交；SQLite 数据库放在 orphan 分支
  （`db` / `db_openvsx`）；
- `check-flake.yml`：`nix flake check`；
- `check-example.yml`：构建 Home Manager 示例；
- `check-unittest.yml`：cargo test；dependabot PR 自动合并。

## 5. 与我们仓库的启发

- 我们 [nix-vscode-extensions](./nix-vscode-extensions.md) 笔记里
  的方案是“预生成扩展集合”；nix4vscode 走 overlay + 自维护数据，
  更灵活但需要自己跑 exporter；
- 如果以后要把用户 VSCode 扩展声明化，nixpkgs 的
  `vscode-with-extensions` 仍是主流，nix4vscode 适合对版本/预发布
  有精细需求的场景。

## 6. 参考

- [nix4vscode](https://github.com/nix-community/nix4vscode)
- [nix-vscode-extensions](https://github.com/nix-community/nix-vscode-extensions)
