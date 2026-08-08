# robotnix 学习笔记

## 1. 是什么

`robotnix` 用 Nix 构建 AOSP/LineageOS/GrapheneOS 镜像，接口类似
`lib.nixosSystem` 的 `lib.robotnixSystem`。

## 2. 核心思路

Android 构建链包含很多独立项目：AOSP、内核、Chromium、MicroG、vendor blobs。
robotnix 用 NixOS 风格模块系统把这些项目统一编排，获得可重现构建和简单签名。

## 3. 示例

```nix
robotnix.lib.robotnixSystem {
  device = "FP4";
  flavor = "lineageos";
  apps.fdroid.enable = true;
  microg.enable = true;
};
```

## 4. 重要限制

- 磁盘建议 250GB+，内存 16GB+；
- `/tmp` 不能是 tmpfs；
- 需要 `CONFIG_USER_NS`；
- 构建时间很长（Chromium + Android 可能需要数小时到一天）；
- 当前是 alpha，正在换 maintainer，部分组件未维护。

## 5. 对我们仓库的启发

我们已有 Android 相关经验（reDroid on Orange Pi Zero 3），但那是移植和
镜像制作，不是 AOSP 常规构建。robotnix 展示了“用模块系统编排多项目构建”
的另一种尺度，和 dream2nix/flake-parts 是同一类思想。

## 6. 参考

- [robotnix](https://github.com/nix-community/robotnix)
- [docs.robotnix.org](https://docs.robotnix.org)
