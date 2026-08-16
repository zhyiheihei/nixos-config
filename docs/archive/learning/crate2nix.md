# crate2nix 增量构建模型学习笔记

## 1. 它解决什么问题

普通 `cargo build` 在 Nix 里经常被当成一个整体 derivation，任何依赖变化都会触发
整棵依赖树重编。`crate2nix` 把 `Cargo.lock` 解析成“一个 crate 一个 derivation”，
这样只有变化的 crate 以及它下游的 crate 需要重建。

## 2. 生成过程的五个阶段

来自 crate2nix 的设计文档：

1. `cargo metadata`：调用 `cargo metadata` 拿完整依赖信息；
2. `indexing metadata`：按 package ID 建立索引，方便把依赖节点和包信息连接起来；
3. `resolving`：把依赖关系解析成 `CrateDerivation`，包含构建所需信息；
4. `pre-fetching`：预取 crates.io 包并计算 sha256；
5. `rendering`：通过 `build.nix.tera` 模板渲染出 `Cargo.nix`。

所以 `Cargo.nix` 不是手写产物，而是生成物；依赖变化后需要重新生成。

## 3. 两种生成策略

### manual（推荐）

```bash
crate2nix generate
nix build -f Cargo.nix rootCrate.build
```

- 无 IFD，Nix 可以保持构建并行度；
- 依赖或影响 `Cargo.lock` 的配置变化时，需要手动重新生成。

### auto（IFD）

```nix
cargoNix = crate2nix.tools.${system}.appliedCargoNix {
  name = "my-project";
  src = ./.;
};
```

- 每次求值都从 `Cargo.lock` 自动生成，始终同步；
- 使用 import-from-derivation，可能降低构建并行度。

## 4. 增量构建为什么成立

生成后的 `Cargo.nix` 里每个 crate 都有独立 derivation，通过 nixpkgs 的
`buildRustCrate` 构建。Nix 的 store 哈希只对“输入变化”的 derivation 失效，
所以：

- 某个 crate 的源码或依赖变化，只重建它及下游；
- 已缓存的上游 crate 直接复用；
- Hydra/二进制缓存、远程构建都能按 crate 粒度生效。

## 5. 逐 crate 覆盖

`crateOverrides` 可以给单个 crate 补 native 依赖、patch 等：

```nix
customBuildRustCrateForPkgs = pkgs: pkgs.buildRustCrate.override {
  defaultCrateOverrides = pkgs.defaultCrateOverrides // {
    openssl-sys = attrs: {
      buildInputs = [ pkgs.openssl ];
    };
  };
};
```

这是 `buildRustCrate` 的既有能力，crate2nix 只是把每个 crate 都变成可覆盖的节点。

## 6. 对我们仓库的启发

当前 `zhyi-packages` 的 Rust 代码只有 `zhconv-rs`，而且是 PyO3/maturin Python
绑定，所以继续走 `buildPythonPackage` + `rustPlatform` 更合理。

如果以后出现独立 Rust 二进制或大 workspace：

- 简单单 crate：优先 `naersk`；
- 大 workspace / 需要精确增量 CI：再考虑 `crate2nix`；
- 需要逐 crate 打补丁：`crate2nix` 的 `crateOverrides` 才是真正优势。

## 7. 参考

- [crate2nix](https://github.com/nix-community/crate2nix)
- [crate2nix docs](https://nix-community.github.io/crate2nix/)
