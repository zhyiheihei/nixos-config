# nh 学习笔记

## 1. 是什么

`nh` 是一个 Rust 编写的统一 Nix CLI，目标是整合并改进 Nix、NixOS、
Home Manager、nix-darwin 的常用命令体验。

## 2. 核心子命令

- `nh os`：替代 `nixos-rebuild`，带构建树展示、diff、确认提示；
- `nh home`：替代 `home-manager`；
- `nh darwin`：替代 `darwin-rebuild`；
- `nh search`：搜索 nixpkgs 包、NixOS/Home Manager 选项、PR、issue；
- `nh clean`：比 `nix-collect-garbage` 更强大的 GC，支持 gcroot 清理、
  profile 定位和按时间保留。

## 3. 与现有工具的关系

`nh` 不是简单 wrapper，而是重新实现；它集成 `nix-output-monitor` 和
`dix` 提供更友好的输出。

## 4. NixOS 集成

```nix
programs.nh = {
  enable = true;
  clean.enable = true;
  clean.extraArgs = "--keep-since 4d --keep 3";
  flake = "/path/to/nixos-config";
};
```

## 5. 对我们仓库的启发

当前我们使用 `make` + `colmena` 做部署，不需要引入 `nh` 作为替代。
如果以后想简化单机 rebuild 或清理体验，`nh` 是值得考虑的候选。

## 6. 参考

- [nh](https://github.com/nix-community/nh)
- [nh docs](https://github.com/nix-community/nh/tree/master/docs)
