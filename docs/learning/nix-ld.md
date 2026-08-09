# nix-ld 学习笔记

## 1. 是什么

`nix-ld` 让 NixOS 能直接运行 **未 patchelf 的动态链接二进制**
（MIT，1687 star）。很多第三方/闭源程序把
`/lib64/ld-linux-x86-64.so.2` 这种动态加载器路径写死在 ELF 里，
NixOS 的 glibc 在 /nix/store，因此跑不起来。

nix-ld 在 `/lib64` 等系统路径放一个 shim，启动时读取环境变量里
指定的真实 loader 和库路径，然后 `exec` 真正的二进制。

## 2. 环境变量

- `NIX_LD`：真实动态加载器路径（例如
  `stdenv.cc.bintools.dynamicLinker`）；
- `NIX_LD_LIBRARY_PATH`：附加库搜索路径，会转成
  `LD_LIBRARY_PATH` 传给真实 loader；
- 支持按 system 后缀的变体 `NIX_LD_x86_64_linux` /
  `NIX_LD_LIBRARY_PATH_x86_64_linux`，方便在配置里按平台指定；
- `NIX_LD_LOG`：error/warn/info/debug/trace 调试。

之所以不直接用 `LD_LIBRARY_PATH`，是因为它会污染所有 Nix 程序
（包括有正确 RPATH 的应用），可能注入错误版本的库。

## 3. 与 FHS 方案的区别

`buildFHSUserEnv` 也能跑未 patch 的二进制，但：

- setuid 程序无法在 FHS sandbox 里执行；
- 不能在里面再用 bwrap / nix build 等 sandbox 工具；
- 需要一个子 shell，direnv 场景不顺手。

nix-ld 直接在进程启动层解决，不引入文件系统沙箱。

## 4. 维护状态

- nixpkgs 从 NixOS 22.05 起内置 `programs.nix-ld.enable`；
- 2024 年 nix-ld-rs（zhaofengli 的 Rust 重写）已合并回本仓库，
  现在主体是 Rust 实现；
- 仓库还提供独立的 `programs.nix-ld.dev` 开发模块，避免和
  nixpkgs 选项冲突。

## 5. 对我们仓库的启发

我们目前没有启用 `programs.nix-ld`：

- 如果以后跑下载的 vscode 二进制、FPGA IDE、游戏或 npm/pip 装的
  动态程序，nix-ld 是最直接的方案；
- 也可以配合 nix-autobahn / nix-alien 自动收集缺失库；
- 配置边界：只给未 patch 的程序注入库，系统包仍走 nixpkgs
  RPATH，避免全局 `LD_LIBRARY_PATH`。

## 6. 参考

- [nix-ld](https://github.com/nix-community/nix-ld)
- [nix-ld 博客说明](https://blog.thalheim.io/2022/12/31/nix-ld-a-clean-solution-for-issues-with-pre-compiled-executables-on-nixos/)
- [nix-ld-rs](./nix-ld-rs.md)
