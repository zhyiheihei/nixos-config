# nix-environments 学习笔记

## 1. 是什么

`nix-environments` 是 nix-community 维护的“out-of-tree shell.nix 集合”，
维护者 `@mic92`。它的目标不是打包项目，而是记录和共享那些构建/开发环境
配置很麻烦的项目的依赖需求。MIT 协议，2018 年创建，当前 302 star /
60 fork。

## 2. 用法

稳定 Nix 直接通过 URL 拉取：

```bash
nix-shell https://github.com/nix-community/nix-environments/archive/master.tar.gz -A openwrt
```

Flakes：

```bash
nix develop --no-write-lock-file github:nix-community/nix-environments#openwrt
```

也可以在自己的 `shell.nix` 里用 `builtins.fetchTarball` 导入后 override；
buildFHSEnv 类的环境不能直接 `overrideAttrs`，一般通过 `extraPkgs` 扩展。
Yocto 环境支持 `callPackage` 覆盖 `stdenv` / `python3` 等参数。

## 3. 环境边界

- 应包含：构建、开发、测试项目所需的依赖；
- 不应包含：编辑器等个人偏好的用户专属工具。

当前约 17 个环境，覆盖 Arduino、buildroot、Firefox、git、GitHub Pages、
Home Assistant、JRuby、Ladybird、nannou、OpenWRT、Phoronix test suite、
SPEC benchmark、Xilinx Vitis、Yocto、ZMK、cc2538-bsl、InfiniSim。

## 4. 实现模式

- `default.nix` 统一 import 各 `envs/<name>/shell.nix`，支持注入 `pkgs`，
  并准备 `allowUnfree` 的 `pkgsUnfree` 变体；
- `flake.nix` 用 `genAttrs` 为五个系统生成 `devShells`；
- 简单环境用 `pkgs.mkShell` + `nativeBuildInputs` / `buildInputs`
  （home-assistant、github-pages、zmk 等）；
- 需要 `/usr` 布局和系统库的项目用 `buildFHSEnv` /
  `buildFHSEnvBubblewrap`（OpenWRT、Yocto），OpenWRT 还专门处理
  gcc-ar/LTO 和 fakeroot 的 bwrap 参数；
- 外部工具链可以直接 `fetchTarball` 引入，例如 ZMK 环境组合
  zephyr-nix 和 pyproject-nix；
- 环境普遍接受 `extraPkgs`，方便用户在不改上游文件的情况下扩展。

## 5. CI 与维护

- `test.yml`：PR / merge_group 上用 `nix-instantiate default.nix`
  做求值检查；
- `.mergify.yml`：打了 `merge-queue` / `dependencies` 标签的 PR 自动进
  merge queue，以 rebase 方式合并；
- 最近一次 CI 运行（2026-06-22）为 success。

## 6. 对我们仓库的启发

- 我们日常开发环境走 home-manager + direnv，不需要引入这套环境集合；
- 如果以后要做 OpenWRT 源码构建、Yocto 固件或 ZMK 键盘固件开发，
  它的 FHS/Bubblewrap 方案和 zephyr-nix 组合是现成参考；
- 它展示了共享环境定义的边界：只放构建依赖、默认参数化、允许
  `extraPkgs` 扩展，别人继承时不需要 fork。

## 7. 参考

- [nix-environments](https://github.com/nix-community/nix-environments)
- [nixify](https://github.com/kampka/nixify)
- [NixOS/templates](https://github.com/NixOS/templates)
