# vs-overlay 学习笔记

## 1. 是什么

`vs-overlay` 是 sbruder 维护的 VapourSynth 插件 overlay（MIT，15
star，Nix，2024-07 后基本停更）：给 nixpkgs 补上 `vapoursynthPlugins`
包集合和两个工具（getnative、styler00dollar-vsgan-trt），配合
nixpkgs 的 `vapoursynth.withPlugins` / `vapoursynth-editor.withPlugins`
使用。

## 2. 包集构成

`default.nix` 分三类：

1. **原生插件**（C/C++/Rust，`prev.callPackage`）：adaptivegrain
   （Rust，postInstall 把 .so 挪进 `lib/vapoursynth`）、addgrain、
   bm3d、dfttest、nnedi3、znedi3 等几十个；
2. **Python 插件**（`buildPythonPackage`）：vsutil、havsfunc、
   lvsfunc、kagefunc、vsTAAmbk 等，用 `callPythonPackage`
   （`callPackageWith final + vapoursynth.python3.pkgs`）构建，这样
   python 插件里也能用 `vapoursynth.withPlugins`；
3. 少量直接复用 nixpkgs：`ffms2 = prev.ffms`、
   `mvtools = prev.vapoursynth-mvtools`。

很多插件带补丁（跳过 OpenCL 测试、适配 VapourSynth R55 format ID、
CMake 里去 git 调用、vsutil 关掉安装期依赖检查但保留测试等）。

## 3. 全量构建测试

- `everything-shell.nix`：一个 shell，把能构建的插件全部塞进
  `vapoursynth.withPlugins`；构建失败的用注释标明原因（例如
  vstrt 需要非再分发 TensorRT、awsmfunc 等未修）；
- `test-build.sh` / CI（PR + 每月一次）：`nix-build everything-shell.nix`
  验证整集，产物推 nix-community cachix；
- 用法支持非 flake overlay 和 flake input 两种。

## 4. 对我们仓库的启发

- 我们不做视频处理，不引入；
- 这是“nixpkgs 缺一个生态的插件集合”时的标准 overlay 写法：
  原生/脚本插件分目录、`recurseIntoAttrs` 暴露、`withPlugins`
  集成、每月全量构建测试；
- zhyi-packages 若未来补某软件生态的批量包，可直接照抄它的
  “everything-shell + 失败原因注释”质量门禁。

## 5. 参考

- [vs-overlay](https://github.com/nix-community/vs-overlay)
