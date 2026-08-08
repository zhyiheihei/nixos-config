# nix-on-droid-app 学习笔记

## 1. 是什么

`nix-on-droid-app` 是 nix-on-droid 配套的 Android App，本质是
[termux-app](https://github.com/termux/termux-app) 的 fork：包名
`com.termux.nix`、应用名 "Nix"，提供在 Android 上使用 nix-on-droid
的终端。当前版本标记为 `0.118.0_v0.3.7_nix`，241 star（fork）。
仓库 README 仍是上游 Termux 的 README，真正改动集中在下游标记
`NIX-ON-DROID: Downstream version` 的部分。

## 2. 与 nix-on-droid 的关系

- nix-on-droid 是 Android 上的 Nix 环境；这个 app 是它的启动器/终端；
- app 内嵌 termux 风格 bootstrap，`packageVariant` 支持
  `apt-android-7` / `apt-android-5` 两种变体；
- 构建只打 `arm64-v8a`，与 nix-on-droid 的目标架构一致。

## 3. 构建方式（Nix + Gradle）

- flake 用 nixpkgs `androidenv` 提供 Android SDK/NDK（platform 28/30、
  build-tools 30.0.3 + 33.0.2 修 aapt2），JDK 11 + Gradle 7.5；
- 用 `gradle2nix` 的 `buildGradlePackage` + `nix/gradle.lock` 做离线
  构建；
- 锁文件通过 status-im 的 `go-maven-resolver` + `url2json` 脚本再生
  （`nix/deps-scripts.nix` 里的 `resolve-gradle-deps` →
  `gen-deps-lock` → `regen-lock` → `build-apk`）；
- release 走 `assembleRelease`，并注入 aapt2 override 修复 AAPT 问题。

## 4. CI

- `debug_build.yml`：push/PR 构建 `apt-android-7` / `apt-android-5`
  两个变体的 debug APK，校验 semver 版本并上传 universal + 各 ABI
  artifact 和 sha256sums；
- `run_tests.yml`：`gradlew test` 跑单测；
- `attach_debug_apks_to_release.yml`：release 发布时自动构建并附加
  APK；
- 另有 gradle-wrapper-validation 和 JitPack 触发工作流。

## 5. 对我们仓库的启发

- 我们不涉及 Android / nix-on-droid，不需要引入；
- 可借鉴“用 Nix 锁 Gradle 依赖 + offline 构建”的路线
  （gradle2nix + `gradle.lock` + go-maven-resolver），以后若复刻
  Android/Java 构建可以直接参考；
- fork 上游时用 `NIX-ON-DROID: Downstream version` 标记本地改动，
  便于跟踪上游，这种复刻纪律和我们对齐作者原版的思路一致。

## 6. 参考

- [nix-on-droid-app](https://github.com/nix-community/nix-on-droid-app)
- [nix-on-droid](https://github.com/nix-community/nix-on-droid)
- [gradle2nix](https://github.com/tadfisher/gradle2nix)
- [termux-app](https://github.com/termux/termux-app)
