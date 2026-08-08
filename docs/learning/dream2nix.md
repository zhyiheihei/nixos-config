# dream2nix 与 drv-parts 学习笔记

## 1. dream2nix 是什么

`dream2nix` 的目标是把多种语言生态的“自动打包”统一到一个模块化框架里，减少
`2nix` 转换器之间的重复代码，并提供统一 UI 和更新机制。

当前状态：API 仍不稳定，正在向 `drv-parts` 重构；老接口在 `legacy` 分支。

## 2. drv-parts 的核心思想

`drv-parts` 把“一个 derivation”拆成一组可组合的 NixOS 风格模块：

- 每个模块声明 `options` 和 `config`；
- 多个模块通过 imports 组合；
- 最终通过模块系统求值出一个 derivation；
- 包可以通过 `extendModules` 继续扩展，而不是只能 `overrideAttrs`。

## 3. core 模块提供了哪些概念

- `public`：最终 derivation 结果，包含 `config` 和 `extendModules`；
- `lock`：lock file 字段、刷新脚本、`invalidationData`、`isValid`；
- `flags`：通过 `flagsOffered` 声明布尔 feature，自动生成 `flags.*`；
- `paths`：项目根、包路径等路径相关选项；
- `deps`：声明外部依赖，例如 `deps = { nixpkgs, ... }: { nodejs = nixpkgs.nodejs_latest; }`；
- `env` / `ui`：开发环境与用户界面相关模块；
- `assertions`：配置断言。

## 4. WIP-nodejs-builder-v3 示例说明组合方式

`WIP-nodejs-builder-v3` 把 `package-lock.json` 解析成 `pdefs`，每个包再组合成
多个子模块：

- `prepared-dev`：开发用 node_modules；
- `dist`：发布产物；
- `prepared-prod`：生产依赖；
- `installed`：最终安装结果；
- `public`：对外暴露的 derivation 集合。

实现里通过 `groups.all.packages.<name>.<version>` 组织包，再用
`_module.args` 注入 `plent`、`fileSystem`、`nodejs` 等上下文。这就是
drv-parts“用模块系统组装包图”的直观例子。

## 5. 和传统 mkDerivation 的区别

```text
传统：
  callPackage ./default.nix { ... } -> mkDerivation

drv-parts：
  modules -> evalModules -> public.config -> derivation
```

传统方式修改包主要靠 `override` / `overrideAttrs`；drv-parts 可以继续 import
模块、改 `config`、用 `extendModules` 组合新行为。

## 6. 对我们仓库的启发

当前 `zhyi-packages` 不需要引入 dream2nix：

- Python 包用 nixpkgs `buildPythonPackage` 足够；
- npm/pnpm 用 `fetchNpmDeps` / `fetchPnpmDeps` 足够；
- Rust 绑定用 `rustPlatform` 足够。

未来如果出现“大量多语言包需要统一管理”的需求，再评估 dream2nix。学习它的
`drv-parts` 模型本身仍然有价值：它展示了 NixOS 模块系统可以复用为“包构造
系统”，这是理解 nixpkgs 之外复杂 Nix 项目的关键一步。

## 7. 参考

- [dream2nix](https://github.com/nix-community/dream2nix)
- [dream2nix docs](https://dream2nix.dev/)
