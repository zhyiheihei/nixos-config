# kde2nix 学习笔记

## 1. 是什么

`kde2nix` 是 K900 的“KDE 6 预发布打包试验场”：在 KDE Plasma 6 /
KDE Frameworks 6 / Qt 6 正式进入 nixpkgs 之前，先把整套 pre-release
包编译、测试、缓存到 nix-community。63 star，2024-02 归档，README
只有一行：已合并进
[NixOS/nixpkgs#286522](https://github.com/NixOS/nixpkgs/pull/286522)，
所以仓库使命完成。

## 2. Flake 结构

```nix
inputs = {
  nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable-small";
  flake-utils.url = "github:numtide/flake-utils";
  pre-commit-hooks = { ... };  # 只跑 alejandra 格式化
};
```

输出：

- `overlays.default`：`final: prev: { kdePackages = final.callPackage ./pkgs/kde {}; }`
- `legacyPackages` / `packages`：overlay 里的 `kdePackages`
- `nixosModules.plasma6`：引入 NixOS module 并自动加 overlay
- `nixosConfigurations.test-vm`：一个可直接起的 Plasma 6 测试 VM
- `devShells.default`：Python（bs4/click/httpx/jinja2/pyyaml）+
  gnutar/jq/reuse，用于重新生成包数据

## 3. kdePackages scope

`pkgs/kde/default.nix` 用 `makeScopeWithSplicing'` 建一个
`kdePackages` 作用域：

- `frameworks` / `gear` / `plasma` 三组包；
- `generated/sources.json` 记录每个包的 `url + hash + version`，
  用 `lib.importJSON` 读入再 `fetchurl`；
- `mkKdeDerivation` 是统一 builder：CMake + Qt6，
  `-DQT_MAJOR_VERSION=6`、`strictDeps`、`separateDebugInfo`、
  `outputs = ["out" "dev"]`、`move-dev-hook`；
- 依赖列表来自 `generated/dependencies.json`，license 来自
  `generated/licenses.json`（自动映射 KDE SPDX 到 nixpkgs
  license，KDE 自造 LicenseRef 也手动映射）；
- 上游还不稳的依赖放 `misc/`（如 kdiagram、phonon、kirigami-addons），
  第三方依赖放 `third-party/`（如 syncthingtray）；
- `all.frameworks/gear/plasma` 是聚合目标：把集合里非 broken 的
  derivation 全部塞进 `runCommand`，用于 CI 全量构建。

## 4. NixOS module

`nixos/modules/services/x11/desktop-managers/plasma6.nix` 复制了
nixpkgs plasma5 module 的形态：

- `services.xserver.desktopManager.plasma6.enable` /
  `enableQt5Integration` / `notoPackage` 等选项；
- 断言不能与 plasma5 同时启用；
- 列出 Plasma 6 运行所需的最小包集（kwin、kde-cli-tools、
  plasma-desktop、plasma-workspace、polkit-kde-agent-1 等）；
- 提供 `environment.plasma6.excludePackages` 精简默认包。

## 5. 数据生成与维护脚本

`maintainers/scripts/kde/` 是这套自动化的核心：

- `collect-metadata.py`：读 KDE 官方 repo-metadata checkout
  （YAML），生成 projects/dependencies/licenses 元数据；
- `generate-sources.py`：对每个包抓 invent.kde.org 的 release
  tarball，算出 SRI hash，并用 Jinja 生成每个包的
  `default.nix`（统一 `mkKdeDerivation { pname = ...; }`）；
- `collect-missing-deps.py`：CMake 找不到依赖时记录“可接受缺失”
  清单（Qt6QuickCompiler、Snapd、OsmTools 等）再人工补；
- `collect-licenses.sh`：解开每个源码包跑 `reuse lint --json`，
  汇总成 `licenses.json`；
- `collect-logs.sh`：从 nix store 拉全部构建日志到 `logs/`。

## 6. CI

GitHub Actions `cache.yml`：push 到 main 后装 Nix，登
`nix-community` cachix，执行
`nix build .#all.frameworks .#all.gear .#all.plasma`，成功即把
pre-release 产物推进公共二进制缓存。这就是“预发布打包试验场”
能快速迭代的原因。

## 7. 对我们仓库的启发

- 我们已用 nixpkgs 的 KDE 6（`plasma-manager` 是其上层），不需要
  引入 kde2nix；
- “先建临时 scope 预发布全量编译，成功后整体 PR 进 nixpkgs”是
  大批量上游化的有效流程，kde2nix 是范例；
- `mkKdeDerivation` + 元数据 JSON 驱动的自动生成模式，对我们以后
  批量包装某生态（比如 zhyi-packages 里的同源软件集）有直接参考
  价值：数据与 builder 分离，脚本只管抓元数据。

## 8. 参考

- [kde2nix](https://github.com/nix-community/kde2nix)
- [NixOS/nixpkgs#286522](https://github.com/NixOS/nixpkgs/pull/286522)
