# luarocks-nix 学习笔记

## 1. 是什么

`luarocks-nix` 是 [LuaRocks](https://github.com/luarocks/luarocks)
的 fork（org 维护者 @teto），给 luarocks 加了一个 `nix` 命令：把
rockspec / rock 直接转换成 `buildLuarocksPackage` 的 Nix derivation。
26 star，MIT，基于 LuaRocks 3.13.0，默认分支 `nix/v3.13`。

```sh
luarocks nix date                       # 按名字从 luarocks.org 搜索
luarocks nix ./foo-1.0-1.rockspec       # 本地 rockspec
luarocks nix --maintainers=teto plenary.nvim
```

要求 lua >= 5.2（5.1 的 `os.execute` 返回值不同）。

## 2. 转换逻辑（cmd/nix.lua）

`src/luarocks/cmd/nix.lua` 的核心：

- 按名字时走 luarocks `search` + `fetch` 找到 rockspec 并下载；
- `url2src` 处理 source 协议：
  - 基本 URL：`nix-prefetch-url` 拿 sha256，再用 `file` 判断
    gzip/zip 选 `fetchurl` / `fetchzip`；URL 落在 luarocks 镜像
    上时改用 `mirror://luarocks/...`；
  - `git` / `git+https`：调 `nurl --indent 2` 生成
    `fetchFromGitHub`/`fetchgit` 源码表达式；
  - `file` 协议直接返回本地路径；
- 依赖转换：Lua 包名 `.` → `-` 映射成 Nix 属性名；对 `lua`
    的版本约束生成 `disabled = luaOlder ... || ...` 表达式；
- 输出 `buildLuarocksPackage`：`pname` / `version` / `src` /
  `knownRockspec`（从 luarocks.org 拿官方 rockspec 的 outPath，
  因为仓库里的 rockspec 常不可用）/ `nativeBuildInputs` /
  `propagatedBuildInputs` / `checkInputs` / `meta`（homepage、
  license、maintainers、description、longDescription）；
- cmake 型 build 自动把 `cmake` 加进 nativeBuildInputs。

## 3. Flake 与 CI

- flake 为 lua5_1..5_5 各产一个 `luarocks-<ver>` 包和 devShell；
  devShell 带 nurl、lua-language-server、luacheck、
  luarocks-packages-updater，shellHook 提示用
  `plenary.nvim` 试验；
- `nix.yml`：装 nix-prefetch-git/nurl 后，逐个跑
  `nix run . -- nix std.normalize`、`lua-iconv`、`cqueues`、
  `digestif`、远端 gitsigns.nvim rockspec；
- 目标是配合 nixpkgs 的
  `maintainers/scripts/update-luarocks-packages` 生成
  `luaPackages` 包集。

## 4. 对我们仓库的启发

- 我们不打包 Lua 生态，不引入；
- 它是“包管理器本身长出一个 Nix 导出命令”的范例，和 npm/pip
  侧的工具一样，源头生成比第三方再造轮子更贴近规范；
- `nix-prefetch-url + file 探测格式`、`mirror://` 归一化、依赖
  约束转 `disabled` 表达式，都是写包生成器时可直接复用的细节。

## 5. 参考

- [luarocks-nix](https://github.com/nix-community/luarocks-nix)
- [LuaRocks](https://github.com/luarocks/luarocks)
