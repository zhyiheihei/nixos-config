# nixos-avf-image-app 学习笔记

## 1. 是什么

`nixos-avf-image-app` 是 [nixos-avf](https://github.com/nix-community/nixos-avf)
（Android Virtualization Framework 里跑 NixOS）的配套安装 App，
mkg20001 维护，45 star，GPL-3.0，Kotlin + Gradle 工程。仓库同时
包含一个 Rust 写的 GraphQL 代理服务和一个 NixOS module。

限制：只支持 Android 16+，主要在 Pixel 上测试过。

## 2. Android App

`app/` 是 Compose Material3 单页应用：

- 用 Apollo GraphQL 客户端拉取 nixos-avf 的 GitHub releases，
  展示镜像和安装说明（markdown 渲染）；
- `libsu` 执行特权命令，`commons-compress` 解压 `tar.gz` 镜像；
- 多种安装方式（`install/` 下按策略类实现）：
  - `DebugInstallMethod`：写入 `/sdcard/linux/images.tar.gz`
    （debug 构建才可用）；
  - `ReplaceInstallMethod`：解压到 `/sdcard/Download/image`，
    放一个 `replace.sh` 到 VM 里替换分区（生产构建默认方式）；
  - `MagiskInstallMethod`：Magisk 变体；
- debug/release 用 `BuildConfig.ALLOW_ANY_METHOD` 区分可用安装
  方式；release 开 minify + shrinkResources。

## 3. Rust 代理服务器

`src/main.rs` 是 Rocket 服务：

- 只暴露 `POST /graphql`，把客户端请求替换成固定的 GitHub
  `GetReleases` GraphQL 查询（`graphql_client` 根据 schema 生成），
  用配置里的 token 转发到 `api.github.com/graphql`；
- 这样 App 不内置 GitHub token，也不用自己拼 GraphQL；
- 配置走 `twelf`：优先 `CONFIG` 环境变量指定的 YAML，再叠加
  `APP_` 前缀环境变量（port/token）。

`module.nix` 提供 `services.nixos-image-proxy-server`：
`Type = "simple"` 的长驻服务 + `DynamicUser`，`config` 用
`pkgs.formats.json` 生成，`openFirewall` 选项控制放行端口。

## 4. Flake 与开发体验

- 输入 android-nixpkgs（tadfisher）：SDK 含 build-tools-35、
  platform-36、emulator；
- `apps`：`build-android` / `install-app` / `logcat-app` / `run-app`
  四个脚本（adb 自动 build + install + launch + logcat）；
- devShell：写入 `local.properties`（`sdk.dir` 和
  `aapt2FromMavenOverride` 指向 Nix 路径），避免 Gradle 找系统 SDK；
- `package.nix`：`rustPlatform.buildRustPackage` 打代理服务器；
- 发布走 fastlane（test / beta / deploy / capture_screen lane），
  Gradle 集成 Sentry；仓库无 GitHub Actions。

## 5. 对我们仓库的启发

- 我们不做 Android 客户端，不需要引入；
- “App 需要 GitHub API 但不想暴露 token”的解法值得记：本地/自有
  服务器做 GraphQL 代理，把 token 留在服务器配置里；
- NixOS module + `DynamicUser` + `formats.json` 生成配置的写法，
  和我们 host 级服务模块的惯用风格一致，可照抄。

## 6. 参考

- [nixos-avf-image-app](https://github.com/nix-community/nixos-avf-image-app)
- [nixos-avf](https://github.com/nix-community/nixos-avf)
