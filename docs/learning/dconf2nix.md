# dconf2nix 学习笔记

## 1. 是什么

`dconf2nix` 是 Haskell 写的转换器：把 `dconf dump` 出来的文本转成
Home Manager `dconf.settings` 期望的 Nix 表达式，让 GNOME Shell 等
GUI 配置可以声明式管理。Apache-2.0，维护者 `@jtojnar`（原作者
gvolpe），2020 年创建，当前 301 star / 11 fork，已进入 nixpkgs。

## 2. 用法

```bash
dconf dump / | dconf2nix > dconf.nix
```

也可以指定输入/输出文件和自定义根路径：

```bash
dconf2nix -i data/dconf.settings -o output/dconf.nix
dconf2nix --root system/locale -i input -o output
```

生成的 `dconf.nix` 作为 Home Manager module import：

```nix
{
  imports = [ ./dconf.nix ];
}
```

输出依赖 Home Manager 的 `lib.hm.gvariant` 构造函数，例如 `mkUint32`、
`mkTuple`、`mkArray`、`mkVariant`。

## 3. 转换流程

- `DConf.hs`：用 parsec 解析 dconf 的 INI 风格格式（`[path]` +
  `key=value`），完整覆盖 GVariant text format：bool、int/double
  （含 hex/octal/scientific）、字符串/byte string、tuple、list、
  dict、variant、cast、typed value 和 JSON 特殊形式；
- `DConf.Data.hs`：自定义 AST；
- `Nix.hs`：把 AST 渲染成 Home Manager gvariant 构造函数表达式；
- 关键点：Nix 与 GVariant 数据模型不同，Uint32/Tuple/ByteString 等
  需要构造函数包一层；负数、函数调用表达式还需要判断是否加括号。

## 4. 工程细节

- Haskell 栈：parsec + optparse-applicative + text，cabal 项目；
- `default.nix` 用 `callCabal2nix`，`shell.nix` 提供 GHC 开发环境
  （cabal-install、haskell-language-server、hlint）；
- 测试：Hedgehog 属性测试 + 18 组 golden 测试，输入在
  `test/data/*.settings`、期望输出在 `test/output/*.nix`，覆盖
  custom root、nested、unicode、emoji、keybindings、typed 等场景；
- CI（Haskell CI）：`cachix/install-nix-action` + `cachix-action`
  缓存 dconf2nix，`nix-shell` 里跑 `nix-build-uncached default.nix`；
  master 最近一次 CI（2026-03-21）为 success。

## 5. 对我们仓库的启发

- 我们目前是 headless 服务器为主，客户端启用 KDE 且
  `programs.dconf.enable = true`，但没声明式管理 GUI 设置；
- 如果以后要把 KDE/GNOME 的 dconf 设置纳入 Home Manager，可以先用
  `dconf dump` + dconf2nix 生成基线，再逐步精简成手写配置；
- 它的“解析器/渲染器分离 + golden 快照测试”结构值得参考。

## 6. 参考

- [dconf2nix](https://github.com/nix-community/dconf2nix)
- [Home Manager dconf.settings](https://rycee.gitlab.io/home-manager/options.xhtml#opt-dconf.settings)
- [GVariant text format](https://docs.gtk.org/glib/gvariant-text-format.html)
