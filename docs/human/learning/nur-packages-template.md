# nur-packages-template 学习笔记

## 1. 是什么

`nur-packages-template` 是 NUR 个人仓库的官方模板，要求用 GitHub
“Use this template”而不是 fork。MIT 协议，159 star，是我们
`zhyi-packages` 这类 NUR 仓库的规范参照。

## 2. 目录与约定

- 根 `default.nix`：接收 `pkgs` 参数（允许默认 `<nixpkgs>`），返回
  包集合；`lib`、`overlays`、`nixosModules`、`homeModules`、
  `darwinModules`、`flakeModules` 是特殊保留属性；
- `pkgs/<name>/default.nix`：每个包一个目录；
- `overlay.nix`：把非保留属性作为 overlay 输出；
- `ci.nix`：筛选可构建/可缓存包——排除 `meta.broken`、非自由
  license、`preferLocalBuild`，并展开 `recurseForDerivations` 和
  所有 outputs；
- `flake.nix`：导出 `legacyPackages` / `packages` / modules。

## 3. CI 模板（build.yml）

- matrix：三个 nixpkgs channel（nixpkgs-unstable、nixos-unstable、
  nixos-26.05）；
- 可选 Cachix（`CACHIX_SIGNING_KEY` / `CACHIX_AUTH_TOKEN`）；
- `nix-env -f . -qa` 做 restrict-eval 求值检查；
- `nix-build-uncached ci.nix -A cacheOutputs` 构建缓存包；
- 最后 `curl -XPOST https://nur-update.nix-community.org/update?repo=<name>`
  通知 NUR 有新版本。

## 4. 与我们的关系

- `zhyi-packages` 走的是 xddxdd 的 NUR 结构（pkgs + flake-modules +
  tools + nvfetcher），不是直接照抄这个模板，但都满足同一份 NUR
  契约：根 `default.nix` 返回包集合、MIT、CI 构建并通知 nur-update；
- 我们 [zhyi-packages-guide.md](zhyi-packages-guide.md) 里的注册
  流程和 [nur-chain.md](nur-chain.md) 与这里完全对应；
- 模板的 `ci.nix` 筛选逻辑（broken/unfree/preferLocalBuild）值得
  参考，我们 build.yml 的 `check-package-meta` 就是在做类似检查。

## 5. 参考

- [nur-packages-template](https://github.com/nix-community/nur-packages-template)
- [zhyi-packages 复刻指南](zhyi-packages-guide.md)
- [NUR 生态链](nur-chain.md)
