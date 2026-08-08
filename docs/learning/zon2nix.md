# zon2nix 学习笔记

## 1. 是什么

`zon2nix` 是 Zig 写的工具，把 `build.zig.zon` 里的依赖转成 Nix
表达式（`deps.nix`）。MPL-2.0，123 star，版本 0.1.2。

## 2. 用法

```sh
zon2nix > deps.nix
zon2nix zls > deps.nix
```

然后在 Nix 包定义里：

```nix
postPatch = ''
  ln -s ${callPackage ./deps.nix { }} $ZIG_GLOBAL_CACHE_DIR/p
'';
```

## 3. 输出

生成 `linkFarm "zig-packages"`，每个依赖按类型生成：

- tarball URL → `fetchzip { url; hash; }`；
- git 依赖（带 rev/ref）→ `fetchgit { url; rev/ref; hash; }`；
- Zig 的 multihash（`1220...`）会被换算成 Nix 的 `sha256-...`。

## 4. 实现

- 用 Zig AST 直接解析 `.zon`，遍历 `dependencies`；
- `Dependency.fromUrl` 处理 URL 重定向和 git 参数
  （rev/ref），用 Nix（`-Dnix` 指定可执行）计算最终 hash；
- `codegen.zig` 按 hash 排序输出稳定表达式；
- flake 用 zig-overlay，同一份源码针对 Zig 0.13 / 0.14 / master
  构建多个包变体。

## 5. CI

- `ci.yml`：macos/ubuntu/arm 矩阵跑 `zig build test`、在 zls 上
  实跑、issue-60 集成测试、`zig fmt --check`；
- `release.yml`：GitHub release + FlakeHub 发布。

## 6. 与我们仓库的启发

- 我们目前没有 Zig 包；如果以后 zhyi-packages 要加 Zig 项目，
  zon2nix 是现成路线（[templates](./templates.md) 里也有 zig
  模板）；
- “解析锁文件 + 用 Nix 计算 hash + 排序输出”和 gomod2nix /
  bun2nix 的思路一致。

## 7. 参考

- [zon2nix](https://github.com/nix-community/zon2nix)
- [Zig](https://ziglang.org)
