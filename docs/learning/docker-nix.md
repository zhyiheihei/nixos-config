# docker-nix 学习笔记

## 1. 是什么

`docker-nix` 是 zimbatm 做的“纯 Nix”Docker 镜像仓库：在
`nixos/nix` 镜像基础上去掉所有 Alpine 依赖，发布为
`nixorg/nix:latest`（另有 `:circleci` tag，额外带 git/openssh）。
37 star，Apache-2.0，**已废弃**，README 明确指向
[docker-nixpkgs](https://github.com/nix-community/docker-nixpkgs)
（我们之前已学）。

镜像刻意不含 channel，默认只留安装好的 Nix，鼓励用户把依赖
完全钉住。

## 2. Dockerfile：multi-stage 到 scratch

第一段 `alpine:3.8` 只当“安装器”：

1. `alpine-install.sh` 下载
   `nix-<release>-x86_64-linux.tar.xz`，sha256 校验（版本和 hash 钉
   在 `version.env`），建 30 个 `nixbld` 用户后跑官方安装脚本；
2. 加 `nixpkgs-unstable` channel，`nix-env -iA` 装
   `bashInteractive` / `cacert` / `coreutils` / `gitMinimal` /
   `gnutar` / `gzip` / `iana-etc` / `xz`；
3. 删 channel、清 store、`nix-collect-garbage -d`、`nix-store
   --verify`，把 /etc/passwd 的 ash shell 换成 bash。

第二段 `FROM scratch` 只拷 `/etc/group`、`/etc/passwd`、
`/etc/shadow`、`/nix`、`/root`，再手工建 `/bin`、`/usr/bin/env`、
`/etc/ssl`、protocols/services 等符号链接；`/tmp` 用 `1777`。
最终镜像里除 Nix store 外没有任何 Alpine 内容。

环境变量包括 `NIX_PATH`、`PAGER=cat`、两套 SSL 证书路径
（`GIT_SSL_CAINFO` / `NIX_SSL_CERT_FILE`），并在
`/etc/nix/nix.conf` 里写 `sandbox = false`（Docker 无特权时
sandbox 不可用）。

## 3. 版本更新

`update.sh`：抓 `nixos.org/nix-release.tt` 的 `latestNixVersion`，
下载 tarball 现场算 sha256，写回 `version.env`。

## 4. 对我们仓库的启发

- 我们不用这个镜像（已归档），构建 OCI 镜像看 docker-nixpkgs；
- “Alpine 只做安装器，scratch 阶段只拷 Nix store + 少量文件”的
  multi-stage 思路，今天仍是用 Nix 做最小镜像的常见手法；
- 版本/校验和钉在 env 文件、脚本自动更新，是简单可靠的“发布
  版本管理”样板。

## 5. 参考

- [docker-nix](https://github.com/nix-community/docker-nix)
- [docker-nixpkgs](https://github.com/nix-community/docker-nixpkgs)
