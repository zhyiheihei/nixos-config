# 自有 Attic 优先与完整闭包缓存

本文记录 2026-07-11 对 `lantian` Attic 缓存的实际检查和修复过程，重点解释：

- 为什么构建机上的系统闭包约 70 GiB，而 S3 只有约 30 GiB。
- 如何让自有 Attic 比 `cache.nixos.org` 优先。
- 如何让自有 S3 真正保存完整闭包，而不是依赖上游缓存。
- 上传中断或出现 502 后如何安全续传和验收。

## 两种不同目标

“自有 Attic 优先”和“完整保存在自有 S3”不是同一个配置。

### 自有 Attic 优先

Nix 会读取每个 binary cache 的 `Priority`。数值越小，优先级越高。
`cache.nixos.org` 的优先级通常是 `40`。

如果 Attic 是 `41`，即使把它写在 `substituters` 的前面，Nix 仍可能优先使用
`cache.nixos.org`。要让自有 Attic 优先，应把 Attic priority 设置为小于 40，
例如 `30`。

目标状态：

```text
Binary Cache Endpoint: https://attic.zhyi.xin:8443/lantian
Priority: 30
```

### 完整保存在自有 S3

Attic cache 可以配置 `upstream-cache-key-names`。如果其中包含：

```text
cache.nixos.org-1
```

`attic push` 遇到已经由官方缓存签名的路径时会显示：

```text
in upstream
```

这些路径不会上传到自己的 S3。要让 S3 独立保存完整闭包，目标状态必须是：

```text
Upstream Cache Keys: []
```

## 本次实际检查结果

`ml-2700u` 最终系统闭包：

```text
/nix/store/l1ah1blhnn7fy7s5jn29cm9y3p8zafzg-nixos-system-ml-2700u-26.11pre-git
```

闭包统计：

```text
paths=9478
narGiB=66.64
```

首次与 Attic PostgreSQL 精确对照：

```text
闭包路径总数：9478
Attic 已缓存：1807
Attic 缺失：7671
```

首次定向推送显示：

```text
1802 already cached, 7660 in upstream, 16 uploaded
```

这证明绝大多数闭包路径因为 `cache.nixos.org-1` 被配置为上游缓存公钥而跳过，
并未写入自己的 S3。

## 为什么 66.64 GiB 不等于 S3 占用

Nix 的 `narSize` 是未压缩 NAR 大小。当前 Attic 配置使用：

```nix
compression = {
  type = "zstd";
  level = 9;
};
```

本次数据库检查曾显示：

```text
有效 NAR 未压缩总量：65 GiB
S3 压缩对象总量：25 GiB
```

因此即使完整上传，S3 占用也不会等于 `nix path-info -Sh` 显示的闭包大小。
压缩、相同 NAR 去重以及其他闭包共享路径都会降低实际对象占用。

判断完整性应比较路径数量和数据库对象，不应只比较 GiB。

## 修改 cache 配置

使用具有 `configure_cache` 权限的 Attic token：

```bash
attic cache configure lantian \
  --priority 30
```

配置上游 key 时，`--upstream-cache-key-name` 可以重复传入。要构建完全独立的
自有缓存，不应保留 `cache.nixos.org-1`。

上传 token 可能只有 `push` 权限。如果 CLI 返回：

```text
AccessError: User does not have permission to complete this action
```

应使用管理员 token。紧急情况下可以在 Attic 数据库所在机器上只修改目标字段，
操作前后都要读取并确认值：

```sql
SELECT name, priority, upstream_cache_key_names
FROM cache
WHERE name = 'lantian';

BEGIN;
UPDATE cache
SET upstream_cache_key_names = '[]', priority = 30
WHERE name = 'lantian';
SELECT name, priority, upstream_cache_key_names
FROM cache
WHERE name = 'lantian';
COMMIT;
```

不要修改 `keypair`，否则所有客户端的 trusted public key 都要重新配置。

## 定向上传完整系统闭包

只推目标系统闭包，不扫描整个 `/nix/store`：

```bash
LOG=/root/attic-ml-2700u-full-independent-$(date +%Y%m%d-%H%M%S).log

HOME=/var/cache/attic-watch-store \
  nix shell nixpkgs#attic-client -c \
  attic push lantian /root/cache-roots/ml-2700u \
  2>&1 | tee "$LOG"
```

正确的完整上传开头应类似：

```text
Pushing ... paths ... (... already cached, 0 in upstream)
```

如果仍显示 `in upstream`，说明 upstream key 尚未清空或客户端读取了错误 cache。

## 502 和中断后的处理

`attic push` 是可重复执行的。已经成功写入的对象会被识别为
`already cached`，不会重新上传，也不会因为最后一次 502 而整体损坏。

本次完整补传在后段遇到：

```text
Error: HTTP 502 Bad Gateway
```

处理方式是检查 atticd 与 Caddy 后，再重复完全相同的定向推送命令。不要清空
Attic 数据库或 S3，也不要删除已经上传的对象。

本次重试后的最终结果：

```text
All done! (9478 already cached, 0 in upstream)
ATTIC_PUSH_RC=0
```

公网 `nix-cache-info` 同时确认：

```text
Priority: 30
```

查看错误：

```bash
grep -Ein 'Bad chunk hash or size|RequestError|Error:|502|Bad Gateway' "$LOG"
```

服务端检查：

```bash
systemctl status atticd.service --no-pager -l
journalctl -u atticd.service --since '30 minutes ago' --no-pager
```

## Hydra 自动上传故障

Hydra 有两条上传路径：

- build 完成后的 `/etc/hydra/post-build`
- 每小时运行的 `hydra-attic-repush.timer`

本次 timer 失败的原因是 `hydra-queue-runner` 的旧 Attic 配置仍指向：

```text
http://[::1]:13803
```

而 atticd 实际只监听：

```text
0.0.0.0:13803
```

因此出现 `Connection refused`。仓库修复要求 `hydra-notify` 和
`hydra-attic-repush` 每次启动前都覆盖登录配置为：

```text
http://127.0.0.1:13803
```

不要只在配置文件不存在时 login，否则旧端点会永久保留。

补传期间可以暂时停止 timer，避免并发 push：

```bash
systemctl stop hydra-attic-repush.timer
```

补传和验收结束后必须恢复：

```bash
systemctl start hydra-attic-repush.timer
systemctl list-timers hydra-attic-repush.timer --no-pager
```

## 数据库健康检查

在 Attic 数据库机器上：

```sql
SELECT state, count(*), pg_size_pretty(sum(nar_size))
FROM nar
GROUP BY state;

SELECT state,
       count(*),
       pg_size_pretty(sum(chunk_size)),
       pg_size_pretty(sum(coalesce(file_size, 0)))
FROM chunk
GROUP BY state;

SELECT count(*) FILTER (WHERE chunk_id IS NULL) AS missing_chunk_refs,
       count(*) AS total_chunk_refs
FROM chunkref;
```

本次修改前检查到 `missing_chunk_refs = 0`，说明已被对象引用的 NAR 没有缺块。
少量 `state = 'P'` 且未被引用的记录通常来自中断上传，不能据此判定已发布缓存
损坏。

## 最终验收标准

1. `attic cache info lantian` 显示 `Priority: 30`。
2. `Upstream Cache Keys: []`。
3. 再次推送闭包时显示 `0 in upstream`。
4. 第二次推送只显示 `already cached`，没有待上传路径。
5. 9478 个闭包路径都能在 `lantian` cache 的 object 表中匹配。
6. `missing_chunk_refs = 0`。
7. 从没有该闭包的测试机仅启用自有 Attic，能够完成 `nix copy` 或系统构建。
8. `hydra-attic-repush.timer` 已恢复运行，日志不再出现 `[::1]:13803`。
