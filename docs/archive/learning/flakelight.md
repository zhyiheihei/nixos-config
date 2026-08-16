# flakelight 模块化 flake 框架学习笔记

## 1. flakelight 是什么

`flakelight` 是一个用 NixOS 模块系统简化 flake 定义的框架。它支持项目、shell、
NixOS 配置、配置 monorepo 等各类 flake。

目标：

- 减少 flake 样板代码；
- 支持配置 vanilla flake 属性；
- 用模块共享公共配置；
- 能自动生成的输出自动生成；
- 提供默认值，但允许关闭或替换。

## 2. 核心能力

- 自动生成 `perSystem` 属性（`packages`、`devShells`、`checks`、
  `formatter` 等）；
- 给定 `package` 定义，自动生成 `packages.<system>.default` 和
  `overlays.default`；
- 自动加载 `./nix` 目录下的 nix 文件（autoload）；
- 提供 `outputs` / `perSystem` 选项，方便从普通 flake 迁移；
- 可以用 `imports` 组合第三方模块。

## 3. 最小示例

```nix
{
  inputs.flakelight.url = "github:nix-community/flakelight";
  outputs = { flakelight, ... }:
    flakelight ./. {
      devShell.packages = pkgs: [ pkgs.hello pkgs.coreutils ];
    };
}
```

这条配置会自动生成每个 system 的 `devShells.<system>.default`。

## 4. 与 flake-parts 的关系

flake-parts 也是“用模块系统组织 flake”的框架，我们的 `nixos-config` 和
`zhyi-packages` 都在用 flake-parts。

区别：

- flake-parts 更底层、更通用，需要自己声明系统列表和输出；
- flakelight 更偏向“开箱即用”，自动生成 package/overlay/devShell/checks；
- flakelight 有 `flakelight-rust`、`flakelight-zig`、`flakelight-darwin`、
  `flakelight-haskell`、`flakelight-treefmt` 等生态模块。

## 5. 对我们仓库的启发

当前 `nixos-config` 使用 flake-parts + 自定义 `flake-modules/`，已经能表达
需要的内容，不需要迁移到 flakelight。

学习 flakelight 的价值在于理解“模块系统如何生成 flake 输出”：它和
`dream2nix` 的 `drv-parts` 一样，都是把 NixOS module system 复用到构建和
输出组织上。

## 6. 参考

- [flakelight](https://github.com/nix-community/flakelight)
- [API Guide](https://github.com/nix-community/flakelight/blob/master/API_GUIDE.md)
