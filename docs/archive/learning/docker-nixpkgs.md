# docker-nixpkgs 学习笔记

## 1. 是什么

`docker-nixpkgs` 是用 Nix 自动构建并发布 Docker/OCI 镜像的仓库，镜像
每天跟随 nixpkgs 刷新。覆盖三个 channel：

- `nixos-unstable` → tag `latest`；
- `nixos-25.11` / `nixos-26.05` → 对应版本 tag，只含安全更新。

MIT 协议（`@zimbatm` 及贡献者），镜像发布到 Docker Hub 和
`docker.nix-community.org`（Scarf 提供自定义域名）。

## 2. 为什么用 Nix 构建镜像

README 列出的优势：

- 构建更可复现，甚至可二进制复现；
- 只重建最小变更集，无需手工维护 Dockerfile 缓存；
- Nix 自动优化 layer；
- 自动获得 nixpkgs 的安全更新。

## 3. 仓库结构

- `images/<name>/default.nix`：每个镜像一个 `callPackage` 定义；
- `lib/importDir.nix`：扫描 `images/` 目录自动 import；
- `lib/buildCLIImage.nix`：通用单二进制镜像，用
  `dockerTools.buildLayeredImage` 叠加 `busybox` + `cacert`，默认
  `Cmd = /bin/<binName>`；
- `lib/mkUserEnvironment.nix`：纯 Nix 生成 `nix-env` 兼容的 user
  profile；
- `overlay.nix`：导出 `buildCLIImage`、`docker-nixpkgs`、
  `mkUserEnvironment`、`gitReallyMinimal`；
- 复杂示例：`images/nix` 用 `buildImageWithNixDb` 和 `fake_nixpkgs`
  做完整 Nix 环境镜像；`images/devcontainer` 用 closureInfo 建 Nix DB
  + profile，并加 VSCode 兼容的 `ld-linux` / `/sbin/ip` 符号链接；
  `images/cachix` 在 nix 镜像基础上加 cachix。

## 4. 发布与 CI

- `.github/workflows/nix.yml`：每日定时 + push + PR 触发，channel ×
  system 矩阵（`aarch64-linux` / `x86_64-linux`），ubuntu runner 用
  QEMU 提供 aarch64，配合 DeterminateSystems nix-installer 与
  magic-nix-cache；
- `ci.sh` 构建全部镜像并 push；`push-all` 用 skopeo 推单架构 tag；
- `ci-manifests.sh` / `generate-manifests` 用 podman manifest 合成
  多架构 manifest 后推送；
- 另有较旧的 `.gitlab-ci.yml`；README 镜像表由 `readme-image-matrix`
  自动生成。

## 5. 对我们仓库的启发

- 我们主机大量使用 podman 容器，但服务镜像大多来自上游 registry，
  没有自建 Nix 镜像；
- 如果以后要把 zhyi-packages 的某个包做成自托管 OCI 镜像，
  `buildCLIImage` 的 `buildLayeredImage + busybox + cacert` 模式可以
  直接套用；
- 多架构发布流程（QEMU 模拟 + skopeo 推单架构 + podman manifest
  合并）值得参考。

## 6. 参考

- [docker-nixpkgs](https://github.com/nix-community/docker-nixpkgs)
- [docker.nix-community.org](https://docker.nix-community.org/)
- [Nixery](https://nixery.dev/)
