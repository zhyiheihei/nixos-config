# cross-toolchains.nix 学习笔记

## 1. 是什么

`cross-toolchains.nix` 是 Mic92 维护的 flake：为 nixpkgs `pkgsCross`
的各种目标**预构建交叉编译工具链**并喂进 nix-community 二进制缓存。
10 star，无 license，2022-07 已归档。目标是“尽早发现交叉编译回归，
并把 nixpkgs 钉到已知可用状态”。

## 2. 内容

- `packages.x86_64-linux`：`pkgsCross` 全量过滤后的包集，排除
  iphone/darwin（Linux 上不支持）、netbsd 废弃别名、
  mips 系列“从未工作过”的目标、vc4（binutils/gcc 坏）等；
- `hydraJobs` 四组矩阵：
  - `stdenv-jobs`：每个目标的 `stdenv`；
  - `hello-jobs`：可执行目标的 `hello`（内核是 `none` 的目标
    没有可执行文件）；
  - `go-jobs`：目标平台的 `buildPackages.go`（另过滤 brokenGo
    列表：s390/mingw32/m68k/ghcjs/redox/wasi/ppc64 等）；
  - `clang-jobs`：已知能构建的 clang 平台（android/musl/riscv64/
    redox/mingw 等）。
- `ci.nix` 就是 `hydraJobs`，直接给 Hercules CI 用。

## 3. CI 与更新

- `upgrade-flakes.yml`：每周用 DeterminateSystems 开
  `update flake.lock` PR（nixpkgs 输入是 Mic92 fork，便于钉
  “已知可用”的 revision）；
- Mergify：`ci/hercules/derivations` 绿 + author 是
  github-actions[bot] 时自动 merge；
- 产物推进 nix-community.cachix.org。

## 4. 对我们仓库的启发

- 我们只在 x86_64/aarch64-linux 原生构建，不引入；
- “stdenv/hello/go/clang 四类冒烟矩阵 + 缓存 + 每周试新 nixpkgs”
  是监控交叉编译回归的标准做法；若以后 ml-builder 要承担交叉
  构建验证，可照抄这个 jobset 划分；
- 它已归档，说明该任务后来基本由 nixpkgs CI / ofborg 承接，也
  值得在笔记里留档。

## 5. 参考

- [cross-toolchains.nix](https://github.com/nix-community/cross-toolchains.nix)
