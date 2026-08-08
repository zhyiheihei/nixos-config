# nix-jetbrains-plugins 学习笔记

## 1. 是什么

`nix-jetbrains-plugins` 是一个 flake，提供 JetBrains Marketplace
上**所有插件**的 Nix derivation，按
`IDE → 版本 → 插件 ID` 三层索引。维护者 theCapypara，56 star，MIT；
每周自动更新，插件列表只覆盖“当前年份 + 去年最后一个 minor 线”。

支持的 IDE 包括 IntelliJ IDEA（含 OSS）、PyCharm、PhpStorm、
WebStorm、RubyMine、CLion、GoLand、DataGrip、DataSpell、Rider、
Android Studio、RustRover、Mps、Aqua、Writerside 等。

## 2. 使用方式

```nix
let
  plugins = nix-jetbrains-plugins.plugins."${system}";
in
pkgs.jetbrains.plugins.addPlugins pkgs.jetbrains.idea [
  plugins.idea."2025.3"."com.intellij.plugins.watcher"
]
```

flake 还导出 `lib` 便捷函数：

- `pluginsForIde pkgs ide pluginIds`：根据 IDE 的 `pname`/`version`
  自动解析对应插件集；
- `pluginsForIdeWith settings pkgs ide pluginIds`：控制
  `applyPluginOverrides`、`dontOverride`、`extraOverrides`；
- `buildIdeWithPlugins pkgs ide pluginIds`：直接产出带插件的 IDE。

## 3. 数据与构建模型

生成数据分两层：

- `generated/ides/<ide>-<version>.json`：IDE 版本 → 插件 ID → 该 IDE
  兼容的插件版本；
- `generated/all_plugins.json`：`"<插件ID>/--/<版本>" → { p, h }`
  （`p` 是 downloads.marketplace.jetbrains.com 上的下载路径，`h` 是
  SRI hash）。

`plugins.nix` 构建时：

- `.jar` 插件直接用 `fetchurl`，目录插件用 `fetchzip`；
- 目录型插件再包一层 `stdenv.mkDerivation`：Linux 上
  `autoPatchelfHook` + `stdenv.cc.cc` lib，统一拷进 `$out`；
- `groupBy'` 把 JSON 折叠成 `IDE → 版本 → 插件` 的 attrset；
- 给 `idea-oss`、`pycharm-community` 等旧名字加别名。

## 4. Rust generator

`generator/` 是 async Rust CLI（tokio + reqwest +
serde-xml-rs + clap）：

- `generate`：拉取 Marketplace 的 `pluginsXMLIds.json` 和
  `jbPluginsXMLIds.json` 索引 + IDE 版本清单，逐个插件取元数据、
  算 hash，写 JSON 数据库；
- `cleanup`：删除不再被任何 IDE 引用的插件；
- `diff`（CI 用）：比较两个 git rev 之间更新的插件列表；
- 输出 SRI hash 用 `nix-base32`，下载失败有 retry 和日志。

devShell 配好 rustup + clang/libclang（bindgen）、openssl/zlib，
`pkg.nix` 用 `rustPlatform.buildRustPackage` 打包。

## 5. CI 设计

- `generate.yml`：每周六生成插件列表并 `cleanup`，用机器人账号
  （`nix-jetbrains-updater`）开 `plugin-updates` PR，配合自定义
  token 触发 PR 上的检查；
- `overrides.yml`：先算“改了哪些 override 目录 + 哪些插件升级”，
  再在 ubuntu / ubuntu-arm / macos 矩阵上逐个
  `nix build pluginsForIde ...`，只测真正受影响的插件；
- `nix-lint.yml`：Nix 文件变更时跑 `nix fmt -- --ci`；
- `generator-lint.yml`：generator 变更时跑 rustfmt + clippy
  `-D warnings`；
- dependabot 管 cargo、GitHub Actions、Nix 三类依赖。

## 6. 插件 overrides

`overrides/<插件ID>/default.nix` 自动加载，针对需要特殊处理的插件：

- GitHub Copilot：官方自带的 native language server 难 patch，
  删掉二进制改用 `makeBinaryWrapper` 包一层 nodejs 跑 JS 版；
- Go 插件：把 nixpkgs 的 `delve` 符号链接进插件自带目录。

`pluginsForIdeWith` 允许关闭默认 override、排除特定插件、或叠加
自己的 override。

## 7. 对我们仓库的启发

- 我们不用 JetBrains IDE，不引入；
- “市场索引 → JSON 数据库 → 通用 mkPlugin + 少量插件 override”
  是 nix-vscode-extensions 同款思路：自动化的核心是数据生成器，
  Nix 侧只做薄解释层；
- 更新 workflow（定时生成 → bot 开 PR → 按 diff 只构建受影响
  插件）比“每天直接 push master”更稳，值得在 zhyi-packages 的
  批量包更新里借鉴。

## 8. 参考

- [nix-jetbrains-plugins](https://github.com/nix-community/nix-jetbrains-plugins)
- [JetBrains Marketplace](https://plugins.jetbrains.com)
