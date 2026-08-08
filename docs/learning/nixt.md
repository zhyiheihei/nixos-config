# nixt 学习笔记

## 1. 是什么

`nixt` 是 Nix 单元测试工具，TypeScript/Ink 写的 TUI CLI，MIT 协议，
作者 Dustin Lacewell，123 star，版本 0.4.0。

## 2. 测试模型

```text
Block      = { path; suites = list TestSuite; }
TestSuite  = { name; cases = list TestCase; }
TestCase   = { name; expressions = list bool; }
```

库函数：`block` / `block'`、`describe` / `describe'`、`it`、
`inject`、`grow`（flake registry 用）。

## 3. 两种运行模式

- standalone：`nixt -p ./nix` 自动发现 `*.test.nix` / `*.spec.nix`，
  文件是 `{ nixt, pkgs }: <Block>`；
- registry：flake 输出 `__nixt = nixt.lib.grow { blocks = ...; }`，
  CLI 读 `.#__nixt`。

CLI 选项：`-p/--path`、`-w/--watch`（chokidar 监听）、
`-v/--verbose`（两次 `-v` 等价 `--show-trace`）、`-l/--list`、
`-d/--debug`。

## 4. 实现

- TypeScript + inversify DI + ink（React 终端渲染）；
- `NixService` 用 `nix eval` 求值测试文件，zod 校验 registry schema；
- flake 用 divnix/std 的 cell 结构组织 devshells/packages/lib/tests。

## 5. CI

- `test.yaml`：`npm ci` + vitest，以及 `nix run .`（用 nixt 自测）；
- dependabot 自动合并，每周自动更新 flake.lock。

## 6. 与 nix-unit 对比

- [nix-unit](./nix-unit.md)：内嵌 evaluator、可测求值失败；
- nixt：外部 `nix eval` + 文件发现 + 漂亮 TUI，适合开发期交互；
- 两者都能覆盖 `{ expr; expected; }` 风格的断言，按喜好选。

## 7. 对我们仓库的启发

- 我们 `helpers/` 若加纯函数测试，nixt 的“文件级 suite/case”
  组织比手写 runTests 直观；
- 它的 registry/standalone 双模式设计值得参考。

## 8. 参考

- [nixt](https://github.com/nix-community/nixt)
- [nix-unit 学习笔记](./nix-unit.md)
