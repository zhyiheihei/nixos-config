# flake-parts 模块机制学习笔记

## 1. flake-parts 是什么

`flake-parts` 是 hercules-ci 维护的 flake 框架，核心目标：

- 用 NixOS module system 组织 flake 配置；
- 提供标准 flake 属性的选项；
- 处理 `system` 维度；
- 让模块可以被其他 flake 复用。

我们的 `nixos-config` 和 `zhyi-packages` 都在使用它。

## 2. perSystem

`perSystem` 是一个函数：`system -> module config`。

```nix
perSystem = { pkgs, ... }: {
  packages.default = pkgs.hello;
};
```

flake-parts 会把它变成：

```nix
packages.<system>.default = ...
```

实现上：

- `allSystems = genAttrs config.systems config.perSystem`；
- 每个 `system` 单独执行一次 `evalModules`，所以配置可以按 system 不同；
- 模块参数提供 `system`、`pkgs`、`inputs'`、`self'` 等；
- 顶层参数如 `self`、`inputs` 在 `perSystem` 里被显式禁止，避免误用；
- `getSystem` 可访问其他 system 的 perSystem 配置。

## 3. transposition

transposition 是“索引交换”：

```text
perSystem: <system>.<attr>
outputs:   <attr>.<system>
```

定义 `transposition.foo = {}` 后，flake-parts 会自动生成
`flake.foo.<system>`，并为 `perInput` 生成反向访问
`input.foo.<system>`。

我们的 `flake-modules/_internal/ci-outputs.nix` 使用的
`flake-parts-lib.mkTransposedPerSystemModule` 就是基于这个机制，把
`perSystem` 里的 `ciPackages` 等转成跨 system 的模块选项。

## 4. moduleWithSystem

`moduleWithSystem` 让一个模块在不同 module system 实例之间复用：

- 先通过 `withSystem system (args: args)` 拿到该系统参数；
- 再把模块以这些参数懒加载进 imports；
- 适合写“既能在 perSystem 里用、也能在 NixOS config 里用”的公共模块。

## 5. flakeModules

`flake.flakeModules` 可以把本 flake 的模块导出给其他 flake：

```nix
flake.flakeModules.default = ./my-module.nix;
```

其他 flake 通过 `inputs.myflake.flakeModules.default` 导入。`nixos-config`
的 `flakeModules.commands`、`flakeModules.lantian-treefmt` 等就是这么组织的。

## 6. 与 flakelight 的对比

- flake-parts：更底层、更通用，是“标准 flake schema 的模块镜像”；
- flakelight：开箱即用，自动生成 package/overlay/devShell/checks；
- 两者都复用 module system，理解一个再看另一个会很快。

## 7. 我们仓库中的实际用法

`flake.nix`：

```nix
flake-parts.lib.mkFlake { inherit inputs; } {
  systems = [ "x86_64-linux" "aarch64-linux" ];
  imports = [ ./flake-modules/... ];
  perSystem = { pkgs, ... }: { ... };
  flake = { ... };
};
```

`flake-modules/_internal/ci-outputs.nix` 使用
`mkTransposedPerSystemModule` 定义 `ciPackages` 等跨 system 选项；
`flake-modules/commands.nix` 使用 `mkPerSystemOption` 定义 `commands`
并转成 `apps` 与 devshell 命令。

## 8. 参考

- [flake-parts](https://github.com/hercules-ci/flake-parts)
- [flake.parts 文档](https://flake.parts)
