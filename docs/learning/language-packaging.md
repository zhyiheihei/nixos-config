# nix-community 语言生态打包学习笔记

本文记录 nix-community 里“把各种语言生态转成 Nix”的仓库，回答两个问题：

1. 每个仓库解决什么问题、现在是否还值得用；
2. 我们的 `zhyi-packages` 为什么没有依赖它们，而是直接用 nixpkgs 自带 builder。

## 1. 仓库全景与维护状态

### dream2nix

- 定位：把多种语言生态统一到一个模块化框架里，目标是取代零散的 `2nix` 转换器。
- 状态：仍在开发，API 不稳定，正在向 `drv-parts` 重构；老接口在 `legacy` 分支。
- 适用：愿意接受不稳定 API、希望一个框架管理 Python/Rust/Go/npm 等多生态时。
- 不适用：只想稳定维护几个个人包时，学习成本偏高。

### poetry2nix

- 定位：解析 `pyproject.toml` 和 `poetry.lock`，自动生成 Python 应用/环境。
- 状态：**unmaintained**；Poetry 2.0 和 PEP-621 支持缺失，官方 README 建议新项目考虑
  `uv` + `uv2nix`。
- 结论：新项目不要从它开始；我们仓库的 Python 包也没有用 Poetry，所以不受影响。

### crate2nix

- 定位：读取 `Cargo.toml`/`Cargo.lock`，生成一个 crate 一个 derivation 的 `Cargo.nix`。
- 优点：增量 CI 精确，远程构建和二进制缓存友好。
- 代价：依赖变化时要重新生成；有 IFD 和 manual 两种策略。
- 适用：大型 Rust workspace、需要精确增量构建时。
- 详细笔记：[crate2nix 增量构建模型](./crate2nix.md)

### naersk

- 定位：最简单的 Rust builder，`naersk.buildPackage { src = ./.; }` 即可。
- 特点：无代码生成、无 IFD、沙箱友好；默认用 nixpkgs 的 rustc，不读
  `rust-toolchain`（除非显式传入工具链）。
- 适用：普通 Rust 二进制包，不想维护生成文件时。

### npmlock2nix

- 定位：解析 `package.json` + `package-lock.json`，提供 `shell`、`node_modules`、
  `build` 三个产物。
- 特点：纯 Nix 实现、无自动生成代码、restricted eval 下可用。
- 适用：npm lockfile 项目，想直接吃 `package-lock.json` 时。

### pnpm2nix

- 定位：把 pnpm `shrinkwrap.yaml` 转成 Nix 表达式。
- 状态：**unmaintained**，只兼容 lockfile v5 及以下；pnpm 10 的维护 fork 在
  `FliegendeWurst/pnpm2nix-nzbr`。
- 结论：新项目不要用它；nixpkgs 的 `fetchPnpmDeps` + `pnpmConfigHook` 已经是更稳的路线。

### napalm

- 定位：基于 `package-lock.json` 构建 npm 包，内置轻量 npm registry 和依赖包 patching。
- 状态：正在找新 maintainer。
- 适用：npm 包需要大量 patching、多个 lockfile 或自定义 nodejs 版本时。

### bun2nix

- 定位：Rust 工具，把 Bun v1.2+ 的 lockfile 转成 Nix 表达式。
- 状态：较新，文档在 GitHub Pages。
- 适用：Bun 项目；目前我们仓库没有 Bun 依赖。

## 2. 选择逻辑

```text
项目简单、nixpkgs 已支持 -> 直接用 nixpkgs builder
项目复杂、需要增量/自定义  -> crate2nix、npmlock2nix、napalm 等专用工具
多语言统一框架            -> dream2nix（接受不稳定）
已经停维护的工具          -> 不要用于新项目
```

## 3. 我们仓库现在用的路线

### Python

`pkgs/python-packages/*` 全部直接使用 nixpkgs 的
`buildPythonPackage`/`python3Packages`，没有用 poetry2nix 或 dream2nix。

原因：

- 包大多是简单 Python 库，`buildPythonPackage` 足够；
- 我们通过 `helpers/group.nix` 把包注入 `python3Packages`，依赖关系由 nixpkgs
  Python 包集合统一处理；
- poetry2nix 已停维护，不值得引入。

### Rust

`zhconv-rs` 是一个 Python 绑定包，用的是
`buildPythonPackage` + `rustPlatform.cargoSetupHook` + `maturinBuildHook`，
而不是 naersk/crate2nix。

原因：它是 PyO3/maturin 产物，本质上属于 Python 包，nixpkgs 原生路线更贴合。
如果以后出现独立 Rust 二进制包，naersk 或 crate2nix 才值得考虑。

### npm / pnpm

仓库里的前端构建统一使用 nixpkgs 原生机制：

- `docker-proxy-hubcmdui`：`fetchNpmDeps` + `buildNpmPackage`；
- `sun-panel`、`filecodebox`、`nexus-media-web`：`fetchPnpmDeps` +
  `pnpmConfigHook`。

原因：

- nixpkgs 的 npm/pnpm 工具是当前维护最活跃的路线；
- 我们还需要写 `npmmirror` registry 和代理相关逻辑，原生 hook 更容易注入；
- `npmlock2nix`/`napalm` 仍可用，但没有必要为现有包引入额外框架。

### Go

`sun-panel`、`docker-proxy` 使用 nixpkgs 的 `buildGoModule` + `vendorHash`，
这是 nixpkgs 标准路线，nix-community 没有对应的必要替代品。

## 4. 结论

当前 `zhyi-packages` 的路线是“nixpkgs 原生 builder 优先，专用 2nix 工具按需引入”。
这是符合维护成本的选择。需要继续观察的点：

- `dream2nix` 稳定后，若未来要管理大量多语言包，可以重新评估；
- `bun2nix` 等新工具出现时，先看它是否进入 nixpkgs 再决定；
- 不要为了“用上 nix-community 工具”而替换已经在工作的 nixpkgs 原生方案。

## 5. 参考

- [dream2nix](https://github.com/nix-community/dream2nix)
- [poetry2nix](https://github.com/nix-community/poetry2nix)
- [crate2nix](https://github.com/nix-community/crate2nix)
- [naersk](https://github.com/nix-community/naersk)
- [npmlock2nix](https://github.com/nix-community/npmlock2nix)
- [pnpm2nix](https://github.com/nix-community/pnpm2nix)
- [napalm](https://github.com/nix-community/napalm)
- [bun2nix](https://github.com/nix-community/bun2nix)
