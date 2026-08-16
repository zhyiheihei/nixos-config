# redoxpkgs 学习笔记

## 1. 是什么

`redoxpkgs` 是一个 Nix overlay，用来把 nixpkgs 里的包交叉编译到
[Redox OS](https://redox-os.org)（`x86_64-unknown-redox`），并能拼出
一个可直接启动的 Redox QEMU 虚拟机磁盘。作者 aaronjanse，63 star；
依赖他 fork 的 `aaronjanse/nixpkgs`（`redox` 分支，为 Redox 补上
`platforms.redox` / `isRedox` 支持）。

## 2. 基本用法

```bash
# 交叉编译 cowsay
nix-build . -A pkgsCross.x86_64-unknown-redox.cowsay

# 把 /nix/store 里的结果拷进 redoxfs 磁盘镜像，再启动 QEMU
redoxfs harddrive.bin /mnt
mkdir -p /mnt/nix/store
cp -r /nix/store/<hash>-cowsay-... /mnt/nix/store
```

flake 输出：`overlay`、四个系统的 `legacyPackages`
（`config.allowUnsupportedSystem = true`）、`packages.redox-vm` /
`redox-vm2`、`apps.redox-vm`（`vm.sh`）。

## 3. overlay：按目标平台裁剪 nixpkgs

`overlay/default.nix` 定义三个 helper：

- `whenHost pkg fix`：仅当 `hostPlatform.isRedox` 时
  `overrideAttrs`；
- `whenTarget pkg fix`：仅当 `targetPlatform.isRedox` 时覆盖；
- `whenAlways`：无条件覆盖。

对 Redox 支持的包做了大量“平台适配”覆盖，典型手段：

- 换源：bash、binutils、curl、openssl、mesa、SDL2 等改用
  gitlab.redox-os.org 的 Redox 分支/补丁版；
- 加 patch：relibc 的 shebang 执行补丁、vim 的 `fsync` 替代
  `sync()`、boehmgc/xz/perl 的静态编译适配；
- 静态化：openssl `no-shared`、perl `--all-static`、mesa
  `--enable-static --disable-dri/glx/egl/gbm` + swrast/osmesa；
- Rust 包统一 `RUSTC_BOOTSTRAP = 1`，放宽工具链版本检查；
- perl 用 `perl-cross` 支持交叉编译；python37 关掉 ncurses/gdbm/
  sqlite 等 Redox 没有的依赖。

## 4. 自定义包：从内核到可启动磁盘

`pkgs/` 里是一整条 VM 构建链：

- `redox-kernel`：`rustPlatform.buildRustPackage` + 自定义 target
  `x86_64-unknown-none.json`，`INITFS_FOLDER` 传入 initfs，
  最后用 `x86_64-unknown-redox-ld` 链接内核并分离 debug symbols；
- `redox-vmdisk`：`redoxfs-fill filesystem.bin <rootfs>` 生成
  500MB Redox 文件系统，再用 nasm 把 bootloader 的 `disk.asm`
  拼成 `harddrive.bin`；
- `redox-vm`：`qemu-img convert` 成 qcow2，生成带
  `-enable-kvm -snapshot -nographic` 参数的 `vm.sh`；
- `rootfs.nix`：`mergeTrees` 把包树 + `farmTrees`（/etc/passwd、
  /etc/shadow、init.d 脚本等文本文件）合成根目录；
- `storeTrees`：用 nixos `make-system-tarball` 导出 closure，
  给每个 bin 生成 Ion 语法 wrapper，实现“把 Nix store 装进 Redox”；
- `redox-binary-rustplatform`：从 IPFS 拉预编译 Redox Rust
  工具链，用 patchelf 修 interpreter/rpath 后做 `makeRustPlatform`；
- `redoxer`：FUSE 工具，Linux 上直接运行 Redox 二进制（配合
  redoxfs）。

## 5. CI：Hydra 而不是 GitHub Actions

仓库没有 GitHub Actions，用的是 `.hydra/` 声明式 jobsets：

- `spec.json`：输入 `nixexpr`（本仓库 master）和 nixpkgs 固定 rev；
- `declarative-jobsets.nix`：生成 master jobset 定义；
- `default.nix`：只构建 `pkgsCross.x86_64-unknown-redox` 里的
  gcc、rustc、hexyl、bash、less、vim、binutils-unwrapped 等关键包。

## 6. 对我们仓库的启发

- 我们目标平台只有 x86_64/aarch64-linux，不需要引入 Redox 交叉链；
- `whenHost`/`whenTarget` 的条件覆盖模式，是我们写
  “只在特定 target 生效”的 overlay/补丁时可以直接用的惯用法；
- “文件系统镜像 = kernel + bootloader + initfs + rootfs 拼接”
  的构造思路，和 disko/镜像生成的层次类似，适合做嵌入式类
  演示时参考；
- `storeTrees` 用 nixos 自带 make-system-tarball 导出 closure，
  比自己遍历 store 可靠得多。

## 7. 参考

- [redoxpkgs](https://github.com/nix-community/redoxpkgs)
- [Redox OS](https://redox-os.org)
