# nsncd 学习笔记

## 1. 是什么

`nsncd`（nix-community fork）是 [twosigma/nsncd](https://github.com/twosigma/nsncd)
的镜像/维护 fork：**不缓存的 nscd 兼容守护进程**，把 NSS 查询代理
给运行它的 libc。Rust，Apache-2.0，4 star，已归档。README 说明：
NixOS 曾用它替换 nscd；上游在 [twosigma/nsncd#71](https://github.com/twosigma/nsncd/pull/71)
补齐 host lookups 支持后，这个 fork 停用。

## 2. 用途

- 大部分 libc 发现 `/var/run/nscd/socket` 存在就会走 nscd，因此
  nsncd 可以让你想用的应用通过“另一套 libc + NSS 插件”做解析，
  而不用改应用；
- 只实现 nscd 协议的一部分，代码量小、可读性好（协议文档主要
  散落在各 libc 实现和邮件列表里）。

## 3. 配置

全部走环境变量：

- `NSNCD_WORKER_COUNT`、`NSNCD_HANDOFF_TIMEOUT`（秒，必须正数）；
- `NSNCD_IGNORE_<DATABASE>`：GROUP / HOSTS / INITGROUPS /
  NETGROUP / PASSWD / SERVICES，设 `true` 时忽略对应请求。

带 systemd unit（`Type=notify`，用 sd-notify）和 Debian 打包。

## 4. 工程

- `src/`：protocol / handlers / ffi / config / work_group（worker
  池），依赖 slog、crossbeam、nix、dns-lookup 等；
- `benches/`：criterion 基准（user）；
- CI：cargo build/test（stable + nightly 定时）、tarpaulin
  coverage 推 codecov、Debian 10 包构建。

## 5. 对我们仓库的启发

- 我们没启用它；NixOS 当前 nscd 替代方案以 nixpkgs 里的 nsncd
  为主（上游已支持 hosts）；
- “fork 承担上游缺的功能、上游合入后归档”是组织常见模式；这个
  仓库与 lila 等一样证明：小而清晰的系统级服务可以长期被 NixOS
  直接消费。

## 6. 参考

- [nsncd](https://github.com/nix-community/nsncd)
