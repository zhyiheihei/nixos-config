# nix-travis-ci 学习笔记

## 1. 是什么

`nix-travis-ci` 是 abathur 做的 Travis CI Nix 引导脚本：几乎可替代
Travis 的 `language: nix`（后者社区维护困难）。MIT，4 star，Shell，
2021-01 后停更。README 状态：Travis 改价后作者基本不再开发新功能，
只接收 PR。

用法（Travis Build Config Imports）：

```yaml
version: ~> 1.0
import: nix-community/nix-travis-ci:nix.yml@main
```

`nix.yml` 提供 `language: shell` + `install: source install.sh` +
`script: nix-build`，还有 `_use_nix` anchor 给 job matrix 里只有
部分 job 需要 Nix 的场景。

## 2. install.sh

- 下载官方 Nix 安装器，传 `--daemon --daemon-user-count 4`；macOS
  11+/10.15+ 加 `--darwin-use-unencrypted-nix-store-volume`；
- 写 `/tmp/nix.conf`：`build-max-jobs = auto`、
  `trusted-users = $USER`，`EXTRA_NIX_CONFIG` 文件内容追加；
- 安装失败自动清理重试 5 次；channel 拉取失败时循环 `nix-channel
  --update` 修复；
- macOS 关 Spotlight 索引 /nix；`CACHIX_CACHE` 存在时自动装
  cachix 并 use；最后打印 Nix/nixpkgs 版本；
- 选项对齐 install-nix-action（内部用 `INPUT_*` 命名）：NIX_TYPE /
  NIX_URL / NIX_PATH / EXTRA_NIX_CONFIG /
  SKIP_ADDING_NIXPKGS_CHANNEL / CACHIX_CACHE。

## 3. 自测矩阵

`.travis.yml` 覆盖：shellcheck、多 Linux dist/osx 镜像默认安装、
curl 冒烟、cachix push、跳过 nixpkgs channel、NIX_PATH 覆盖、
指定 NIX_URL 版本、extra config 生效。

## 4. 对我们仓库的启发

- 我们 CI 已用 GitHub Actions + install-nix-action，不需要它；
- 它演示了“一个 shell 脚本 + 配置片段导入”的 CI 引导方案，
  也解释了 install-nix-action 各类选项的来源（两者刻意对齐）；
- 历史仓库的价值在于留档和替代关系，不用深入维护。

## 5. 参考

- [nix-travis-ci](https://github.com/nix-community/nix-travis-ci)
