# haumea 学习笔记

## 1. 是什么

`haumea` 是“文件系统模块系统”：把一个目录树自动映射成 Nix attribute set，
减少手动 import。

示例：

```text
foo/
  bar.nix
  baz.nix
  __internal.nix
bar.nix
_utils/foo.nix
```

会变成：

```nix
{
  foo = { bar = ...; baz = ...; };
  bar = ...;
}
```

## 2. 核心概念

- `loader`：控制文件如何加载；
- `transformer`：控制树如何转换；
- `self` / `super` / `root`：支持自引用和 fixed point；
- visibility：`_utils` 这类目录可以控制可见性；
- 它不是 NixOS module system 的替代品，更像传统语言的模块系统。

## 3. 为什么有用

- 目录结构即配置结构；
- 免去大量手写 `import ./xxx.nix`；
- 适合大型配置 monorepo。

## 4. 对我们仓库的启发

`nixos-config` 目前使用 flake-parts + 显式 `hosts/` 扫描，不需要迁移。
`haumea` 适合“按目录自动加载”的项目，类似 Snowfall Lib 的思路。

## 5. 参考

- [haumea](https://github.com/nix-community/haumea)
- [haumea docs](https://nix-community.github.io/haumea/)
