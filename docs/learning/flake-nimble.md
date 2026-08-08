# flake-nimble 学习笔记

## 1. 是什么

`flake-nimble` 是 Emery Hemingway 做的实验性 flake：自动生成
[Nimble](https://github.com/nim-lang/nimble) 包索引的 Nix 包集。
38 star，无明确 license，2023-03 后基本停更。

```shell
nix run nimble#fugitive     # 构建并运行一个 Nimble 二进制
nix dev-shell nimble        # 进入带 Nim/Nimble 的开发环境
```

## 2. 数据：packages/<name>.json

每个 Nimble 包一个 JSON，记录全部历史版本：

```json
{
  "homepage": "...",
  "versions": [
    {
      "nimble": { "author", "description", "license", "requires", ... },
      "source": { "url", "rev", "sha256", "date", "method": "git", ... },
      "version": "0.11.3"
    }
  ]
}
```

`nimble` 段来自包的 `.nimble` 文件（version、requires、
bin/binDir/srcDir/foreignDeps 等），`source` 段是
`nix-prefetch-git` / `nix-prefetch-hg` 的输出，可直接喂给
`fetchgit` / `fetchhg` 做 fixed-output 源码。

## 3. overlay 生成包

`overlay.nix` 用 `prev.nimPackages.overrideScope'` 重开一个 scope：

- 对每个 JSON 取**最新版本**，按 `source.method` 选 `fetchgit` /
  `fetchhg`，`subdir` 支持子目录源码；
- `pname` 把 `.` 换成 `_`（Nix 属性名习惯），HEAD 版本用
  `source.date` 前 10 位当版本号；
- `propagatedBuildInputs` 按 `.nimble` 的 `requires` 映射到
  `final'` 里的包；缺少的依赖记进 `missingDependencies`；
- 统一 `buildNimPackage` + `doCheck`，meta 用 nimble 的
  description/license；
- `overrides.nix` 对构建不了的包打补丁（例如给 `alsa`、
  `ncurses`、`sdl2` 补 `propagatedBuildInputs`，`inim` 加 patch +
  关测试）。

scope 里还保留 `nim` / `nimrod` 别名和 `package-updater`。

## 4. package-updater

`src/package_updater.nim` 是 Nim 写的更新器：

- 基于打过 patch 的 nimble 0.11.0 源码（json/subdir/tempdir/url/
  foreignDeps 五个 patch）；
- 对每个包用 nimble 库逻辑列远端 git tags 版本，逐版本 `nix-prefetch-git`
  （带 `--fetch-submodules`）或 `nix-prefetch-hg` 拿 fixed-output
  元数据，再解析 `.nimble` 文件信息；
- 保留旧版本数据，合并出新 JSON；无 tag 的包记成 `HEAD`；
- 更新命令：`nix run .#package-updater generate [包名]`。

## 5. 工程细节

- flake 只有 nixpkgs 输入；`packages` 从 overlay 的
  `nimPackages` 过滤出 derivation 暴露；
- `setup-hook.sh` 给 nimFlags 加 `--path`；`init.sh` 是 vendored
  choosenim 安装脚本（给 Nim 开发 shell 用）；
- `nix.nimble` + `src/` 是仓库自带的示例“Nix 语言库”包；
- 无 GitHub Actions；同步靠维护者手动跑 package-updater。

## 6. 对我们仓库的启发

- 我们不用 Nim，不引入；
- 它和 nix-jetbrains-plugins / nixpkgs-terraform-providers-bin
  一样是“生态索引 → JSON 元数据 → 通用 builder 自动生成包集”，
  区别是这里用 `overrideScope'` 直接扩充 nixpkgs 现成 scope，
  集成度最高；
- “保留旧版本数据 + 只补新增”的增量更新策略，比每次全量重扫
  省事，适合批量生成场景。

## 7. 参考

- [flake-nimble](https://github.com/nix-community/flake-nimble)
- [Nimble](https://github.com/nim-lang/nimble)
