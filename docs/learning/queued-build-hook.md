# queued-build-hook 学习笔记

## 1. 是什么

`queued-build-hook` 是一个 Go 写的 Nix post-build-hook 增强器
（org 清单维护者 @jfroche，meta 里维护者是 adisbladis）：把 Nix
每次构建后同步执行的 post-build-hook 变成“client 入队 + daemon
异步执行”，支持重试、并发和 `wait` 等待。
30 star，MIT，Go + NixOS module。

Nix 的 post-build-hook 同步跑会阻塞构建，且失败没有重试；这个工具
把入队脚本（几乎瞬间完成）和真正的 hook（拷贝到缓存、上传等）
拆开。

## 2. 三个命令

```sh
queued-build-hook daemon \
  --hook ./realhook.sh \
  --retry-interval 1 --retries 5 --concurrency 0

queued-build-hook queue --socket /run/.../hook.sock [--tag x]
queued-build-hook wait  --socket /run/.../hook.sock [--tag x]
```

- `daemon`：监听 Unix socket，把每个任务用
  `DRV_PATH` / `OUT_PATHS` 环境变量传给真实 hook，失败按
  `retry-interval` 重试，超过 `retries` 丢弃并打日志；
  `concurrency 0` 表示不限并发；
- `queue`：Nix post-build-hook 实际调用的入口，向 daemon 发送
  JSON envelope（action=queue）；
- `wait`：阻塞直到队列清空（可带 tag），用于部署前确保所有
  上传/同步任务完成。

## 3. Daemon 设计

`daemon.go` 用单 goroutine 协调：

- `connections` / `queueRequests` / `queueCompleted` /
  `waitRequests` 四个 channel 串起 socket 连接、入队、完成、
  wait 注册；
- worker 池执行 hook；完成后向 `queueCompleted` 上报，主循环维护
  `inProgress` 和按 tag 的计数，清零时唤醒对应 waiter；
- socket 由 systemd 激活（`systemd.go` 解析 `LISTEN_PID` /
  `LISTEN_FDS`，`FD_CLOEXEC` 过滤），配合
  `FileDescriptorStoreMax=1` 可无中断重启。

## 4. NixOS module

`module.nix` 的 `queued-build-hook` 选项：

- `enable` / `package` / `socketDirectory` / `socketUser` /
  `socketGroup`（默认 nixbld 可写）；
- `retryInterval` / `retries` / `concurrency`；
- `enqueueScriptContent`：可自定义入队逻辑（例如某些包改同步
  `wait`）；
- `postBuildScript` / `postBuildScriptContent` 二选一（assertion
  强制）；
- `credentials`：`UPPER_SNAKE` 键作为环境变量、其他作为文件，
  通过 systemd `LoadCredential` 挂载到
  `$CREDENTIALS_DIRECTORY`。

接线：`nix.settings.post-build-hook` 指向入队脚本；systemd socket +
service（`DynamicUser`、`KillMode=process`、`Restart=on-failure`、
`StateDirectory`）。

## 5. 测试与 CI

- `tests/simple.nix`：NixOS 测试里真跑 `nix-build hello`，断言
  `/var/nix-cache` 出现 narinfo、daemon 日志能读 secret env/file、
  `$HOME` 可用；
- `tests/multipleHosts.nix`：两个节点，ci 构建后通过 ssh
  `nix copy` 上传到 cache 节点（演示 credential 文件用法）；
- flake：devshell + treefmt（nixpkgs-fmt/gofumpt/deadnix）+
  pre-commit；CI 靠 bors.toml/Mergify 排队（Buildbot 跑 nix-eval
  和 NixOS 测试）；GitHub Actions 只有
  `update-flake-lock.yml`（每周两次开 merge-queue 标签 PR）。

## 6. 对我们仓库的启发

- lila（已学）正是用它做异步签名上报；如果我们以后要在多台
  builder 上做“构建后上传缓存/签名”且不想阻塞构建，这是现成
  方案；
- “轻 client 入队 + 重 daemon 执行 + wait 语义”是异步任务拆分的
  好模板；
- systemd socket activation + LoadCredential 的安全接线（不给
  hook 常驻密钥，只在启动时挂载）值得直接照抄。

## 7. 参考

- [queued-build-hook](https://github.com/nix-community/queued-build-hook)
