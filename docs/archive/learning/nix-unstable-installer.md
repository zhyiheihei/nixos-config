# nix-unstable-installer 学习笔记

## 1. 是什么

`nix-unstable-installer` 是 NixOS/nix 的配套项目：把 Hydra 上
`nix:master` jobset 的最新成功构建转成 GitHub Releases，提供
install 脚本、tarball、静态二进制和容器镜像。MIT（Numtide），
103 star。

## 2. 用法

```sh
sh <(curl -L https://github.com/nix-community/nix-unstable-installer/releases/download/<release>/install)
```

GitHub Actions 用 `cachix/install-nix-action` 的 `install_url` 指向
对应 release；容器用 `ghcr.io/nix-community/nix-unstable-installer/nix:<version>`。

## 3. update.rb 流程

1. 从 Hydra 拿 `nix/master` 最新 evaluation；
2. 检查必需 job：`build.x86_64-linux`、各平台 `binaryTarball.*`、
   `buildStatic.*`、`dockerImage.*`、`installerScript`；
3. 已存在同名 tag 则跳过；
4. 下载全部产物，把 install 脚本里的
   `releases.nixos.org/nix/` URL 改成本仓库 release URL；
5. 用 ERB 渲染 `RELEASE.md`，输出 `nix_release` / `updated`。

## 4. release.yml

- 每周（或手动）跑 update → 打 tag → 创建 prerelease；
- ubuntu/macos 上用新 install 脚本装 Nix 并跑 `nix-info`，Linux 还
  拉容器镜像验证；
- 全部通过后把容器镜像推到 GHCR（multi-arch manifest + latest），
  再把 release 标记为正式版。

## 5. 对我们仓库的启发

- 我们用稳定/不稳定 channel 即可，不需要 Nix master 预发布；
- 它的“Hydra 产物 → release + 多平台测试 + 容器发布”流水线是
  nightly build 发布的参考模板。

## 6. 参考

- [nix-unstable-installer](https://github.com/nix-community/nix-unstable-installer)
- [NixOS/nix](https://github.com/NixOS/nix)
