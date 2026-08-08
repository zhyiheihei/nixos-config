# nixpkgs-xr 学习笔记

## 1. 是什么

`nixpkgs-xr` 是 NixOS 上 bleeding-edge XR/AR/VR 包的 Nixpkgs
overlay，包包括 Monado、WiVRn、OpenComposite、LOVR、libsurvive、
Proton GE RTSP 等。MIT + REUSE 规范，维护者 Scrumplex（Sefa
Eyeoglu），102 star。

## 2. 使用

```nix
inputs.nixpkgs-xr.url = "github:nix-community/nixpkgs-xr";
# ...
modules = [ nixpkgs-xr.nixosModules.nixpkgs-xr ];
```

该 NixOS module 会同时加 overlay 和 nix-community Cachix 缓存；
也可手动 `nixpkgs.overlays = [ nixpkgs-xr.overlays.default ]`。

## 3. 架构

- `nvfetcher.toml` 逐包声明来源（GitHub/GitLab git、cargo_lock、
  extract 文件），`_sources/` 存锁定的 rev/hash；
- `pkgs/overlay.nix` + `pkgs/overrides/*.nix` 定义包；
- flake 用 flake-utils `meld` 组合 development/lib/nixos/pkgs/tools；
- README 的包列表由 `nix run .#update-readme` 自动生成。

## 4. CI

- `ci.yaml`：treefmt 格式检查、README 同步检查、REUSE 合规；
- `nvfetcher.yaml`：每天 `nix flake update` + `nvfetcher
  --commit-changes`，自动开 PR 并 merge。

## 5. 与我们仓库的启发

- 我们 zhyi-packages 就是同类架构：`nvfetcher.toml` + `_sources/` +
  overlay + 自动更新 PR，nixpkgs-xr 是很好的对照案例；
- 可以学它的 `pkgs/overrides` 分文件组织、README 自动生成和 REUSE
  license 合规检查。

## 6. 参考

- [nixpkgs-xr](https://github.com/nix-community/nixpkgs-xr)
- [nvfetcher](https://github.com/Red-M/nvfetcher)
