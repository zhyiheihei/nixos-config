# Attic 缓存策略

自有 Attic 优先、是否完整镜像上游缓存、以及 S3 占用大小是三件不同的事。

## 优先级

Nix 依据 binary cache 的 `Priority` 选择下载源，数值越小优先级越高。配置
`substituters` 的排列顺序不能替代服务端优先级。

```bash
attic cache info lantian
curl -fsS https://attic.zhyi.xin/lantian/nix-cache-info
```

只有持有 `configure_cache` 权限的管理员才可以修改 priority。修改前后都必须记录
`attic cache info` 的输出；不要绕过 Attic CLI 直接写 PostgreSQL。

## 上游缓存与独立性

若 Attic cache 配置了 `upstream-cache-key-names`，`attic push` 可能显示
`in upstream`，表示已被信任的上游签名覆盖而跳过上传。这能节约自身 S3 空间，但不
代表自有 S3 保存了完整闭包。

若目标是离线/独立可恢复的闭包缓存，应由管理员将 upstream key 列表设为空，并在
目标系统闭包上重跑补推；不能扫描或盲推整块 `/nix/store` 来代替闭包验收。

## 容量判断

`nix path-info -Sh` 给出的 NAR 大小是未压缩值。Attic 当前使用 zstd 压缩，并会共享
重复对象，因此 S3 bucket 的实际占用通常明显更小。完整性应以以下证据判断：

1. 目标系统 root 的闭包路径都可由 Attic 下载。
2. 第二次 `attic push` 不再有待上传路径。
3. 新机器只启用 Attic 时可以复制该闭包或完成安装。

出现 502 或网络中断后，可以重复相同的定向 `attic push`；已完成对象会去重。先检查
Attic 与反代日志，不要因单个错误就清空数据库或 S3。
