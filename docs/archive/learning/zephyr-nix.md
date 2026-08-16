# zephyr-nix 学习笔记

## 1. 是什么

`zephyr-nix` 用 Nix 开发 [Zephyr](https://www.zephyrproject.org/)
项目：打包 Zephyr SDK 工具链、hosttools 和 west Python 环境。
作者 adisbladis，86 star。

## 2. 提供的包

- `sdk`：最小 SDK，可按 `targets` override（例如
  `arm-zephyr-eabi`）；
- `sdkFull`：全部 target；
- `hosttools`：官方二进制 hosttools（部分工具因 libc 不兼容）；
- `hosttools-nix`：全部改用 nixpkgs 工具（bossa、dtc、openocd、
  qemu、gcc_multi 等）；
- `pythonEnv`：基于 Zephyr `scripts/requirements.txt` 的 west
  环境（pyproject-nix 渲染）；
- 多版本 SDK：`sdks."0.16"`、`"0.17"`、`"1_0"`，flake 折叠成
  `sdk-0_16` / `sdkFull-1_0` 等扁平属性。

## 3. 实现

- `sdks/<version>.json` 存 SDK release 文件 sha256，
  `update-sdk` 从 sdk-ng release 的 `sha256.sum` 生成；
- `sdk.nix` 按平台/架构选择 minimal + toolchain tarball，
  autoPatchelf 处理 Linux 二进制，安装后写
  `ZEPHYR_SDK_INSTALL_DIR` setup hook；
- flake pin `zephyrproject-rtos/zephyr` v4.3.0 作为源码输入。

## 4. CI

- 用 [nix-github-actions](nix-github-actions.md) 生成矩阵，只跑
  显式版本化的 SDK 属性，避免重复构建 latest。

## 5. 与我们仓库的启发

- 我们 [nix-environments](nix-environments.md) 笔记里的 ZMK 环境
  就组合了 zephyr-nix；
- 如果以后要开发键盘固件（ZMK）或嵌入式 Zephyr 项目，直接用
  zephyr-nix 的 SDK + pythonEnv 即可，不用自己维护工具链。

## 6. 参考

- [zephyr-nix](https://github.com/nix-community/zephyr-nix)
- [west2nix](https://github.com/adisbladis/west2nix)
