# nixGL 学习笔记

## 1. 是什么

`nixGL` 解决 **非 NixOS Linux 上 Nix 程序打不开 OpenGL/Vulkan**
的问题（1013 star）。Nix 程序通常带 Mesa/Nvidia 库，但宿主系统
的 libGL/驱动环境和 Nix 程序期望的不一致，会出现
`libGL error: unable to load driver: i965_dri.so`。

nixGL 提供包装脚本，启动时注入正确的 GL/Vulkan 库和驱动路径。

## 2. 常用 wrapper

OpenGL：

- `nixGLDefault`：自动检测 Nvidia，没有就回退 Mesa；
- `nixGLNvidia` / `nixGLNvidiaBumblebee`：专有 Nvidia 驱动；
- `nixGLIntel`：Mesa（intel/amd/nouveau）。

Vulkan：

- `nixVulkanNvidia`：专有 Nvidia；
- `nixVulkanIntel`：Mesa，并设置 `VK_LAYER_PATH`。

用法：

```bash
nixGL program args
nixVulkanIntel $(nix run nixpkgs#vulkan-tools -- vulkaninfo)
```

## 3. 接入方式

- `nix-channel` + `nix-env -iA nixgl.auto.nixGLDefault`；
- flake：`nix run github:nix-community/nixGL -- program`（注意
  nixGL 和程序要用同一 nixpkgs 版本，否则 glibc 版本不匹配）；
- overlay：`pkgs.nixgl.nixGLIntel` 等；
- `nixGLCommon nixGLIntel` 生成带 fallback 的短名 wrapper。

## 4. 限制

- 主要针对非 NixOS；NixOS 上一般直接
  `hardware.graphics.enable` 就能工作；
- 自动测试困难（需要真实 GPU），仓库自述“badly tested”；
- Nvidia 自动检测失败时需显式传驱动版本。

## 5. 对我们仓库的启发

- 我们 client 是 NixOS，不需要 nixGL；
- 但如果有 Mac/非 NixOS 开发机要跑 Nix 打包的 GUI 工具，可以用
  它；Mac 上不适用 GL wrapper，只能跑无 GL 程序；
- 它和 nix-ld 一样，本质都是“给 Nix 程序补上宿主系统缺失的
  ABI 边界”。

## 6. 参考

- [nixGL](https://github.com/nix-community/nixGL)
