# 私有 Attic + S3 缓存架构

当前缓存名、公开端点与公钥只以
[`helpers/constants/nix.nix`](../../helpers/constants/nix.nix) 为准。不要在文档、Shell
历史或 Git 提交中复制上传 token、S3 access key、S3 secret key 或 Attic 私钥。

## 当前结构

```text
Hydra (ml-builder) / 手动构建 (ml-builder)
  -> attic push zhyi
  -> Attic (greencloud-jp)
  -> PostgreSQL + VaultS3 (greencloud-jp 本机, s3.zhyi.xin) bucket nix-cache
  -> 持有只读 token 的受管 Nix 主机
```

- Attic 服务、Nginx vhost 与 S3 参数定义在
  [`nixos/optional-apps/attic.nix`](../../nixos/optional-apps/attic.nix)，由
  `hosts/greencloud-jp/configuration.nix` 导入（2026-09 自 greencloud 迁入）。
- S3 后端 2026-09-04 自家中 VaultS3（vaults3.zhyi.xin:8443，home-ddns）切到
  greencloud-jp 本机实例（s3.zhyi.xin）：跨境大对象上传会被中间链路切断
  （CI push-cache 对 zcode 这类 1GB 闭包必然失败），且同机链路零出口流量。
  当日弃用旧缓存并新建数据库；`zhyi`、`lantian` 两个 cache 按旧 keypair
  重建（公钥不变，客户端无需改配置）。
- atticd 的 S3 凭据改由 `hosts/greencloud-jp/configuration.nix` 的
  `sops.templates.atticd-s3-credentials` 提供（本机 VaultS3 统一凭据，与
  Gitea 相同），经 unit 层多 EnvironmentFile 追加并覆盖 `AWS_*`；JWT 签名
  密钥仍来自 `common/attic.yaml`。
- Attic 只监听回环地址，由同机 Nginx 发布；外部数据面使用
  `https://attic.zhyi.xin/zhyi`（标准 443 端口）。
- 缓存名 2026-09-03 自 `lantian` 改为 `zhyi`：服务端复制 cache 行并保留同一
  keypair（公钥值不变，仅名字前缀变）；`lantian` 缓存保留作回滚。
- `lantian` 已于 2026-07-30 切换为 private；匿名请求返回 `401`，不再提供公开
  substituter。
- S3 凭据与上传 token 只在私有 secrets 仓库的 `common/attic.yaml` 中以 SOPS 加密
  保存。修改它必须遵循 secrets 仓库的 `docs/sops-manual.md`。
- 全体受管主机只通过 `common/nix.yaml` 的 `nix-netrc` 获得 `zhyi` 的读取权限。
  上传凭据只部署到 `ml-builder`；Hydra 自动上传与手动上传都由它承担。2026-08-12
  迁移后 `pve-5700u` 不再部署上传 token。
- Hydra 在
  [`nixos/optional-apps/hydra/default.nix`](../../nixos/optional-apps/hydra/default.nix)
  中通过 post-build hook 上传成功构建的输出。不要同时在多台机器启用
  `attic-watch-store`，否则会制造重复上传和难以判断的失败日志。

## 权限模型

| 凭据 | 保存位置 | 部署范围 | 权限 |
| --- | --- | --- | --- |
| Attic fleet read token | `common/nix.yaml` 的 `nix-netrc` | 所有受管主机 | 仅 `pull lantian`、`pull zhyi` |
| Attic upload token | `common/attic.yaml` 的 `attic-upload-key` | 仅 `ml-builder` | `pull/push lantian`、`pull/push zhyi` |
| Attic JWT 签名密钥 | `common/attic.yaml` 的 `attic-credentials` | 仅 `greencloud-jp` 的 `atticd` | 服务端管理与 token 签发 |
| Attic S3 连接凭据 | `hosts/greencloud-jp/configuration.nix` 的 `sops.templates.atticd-s3-credentials`（本机 VaultS3 统一凭据，多 EnvironmentFile 覆盖 `AWS_*`） | 仅 `greencloud-jp` 的 `atticd` | 对 s3.zhyi.xin 的对象读写 |
| Cache public key | `helpers/constants/nix.nix` | 公开配置 | 只用于验证 NAR 签名 |

Bearer token 识别的是“持有凭据者”，不是机器硬件本身。这里的“只有我的主机”是通过
SOPS 只向受管主机部署 token 实现的；如果某台主机泄漏 token，应立即生成新 token、
更新 secrets 并重新部署。不要把 `nix-privkey` 当作 Attic token：Attic 的缓存签名
私钥由服务端管理，客户端和上传端都不应持有它。

## 客户端使用

客户端的默认 substituter 与公钥由 `LT.nix.attic` 统一提供。NCPS 客户端先请求
Attic，再回退到本机 NCPS；该顺序定义在
[`nixos/optional-apps/ncps-client.nix`](../../nixos/optional-apps/ncps-client.nix)。

安装环境或临时 shell 不应手写长期 `/etc/nix/nix.conf`。仅在尚未加载目标配置时，
从 `helpers/constants/nix.nix` 读取当前 URL 和公钥后，以一次性的 `NIX_CONFIG` 传入。

## 健康检查

私有缓存的 netrc 内容如下，token 不得直接写进本仓库：

```netrc
machine attic.zhyi.xin
login attic
password <仅含 pull zhyi 权限的 JWT>
```

`nixos/minimal-components/nix.nix` 按作者原有模式，通过
`nix.settings.netrc-file` 将该文件交给 Nix。这里必须使用真实换行，不能把 `\n`
两个字符写进 SOPS 字符串。在任意已配置客户端上：

```bash
curl --fail --netrc-file /run/secrets/nix-netrc \
  https://attic.zhyi.xin/zhyi/nix-cache-info
```

`nix store ping` 只验证 store URL，不能单独证明私有缓存认证和对象读取成功。
普通 `curl` 也不会自动使用 Nix 的 netrc，因此检查时必须显式指定
`--netrc-file`。

当前已验证 `ml-builder`、`router` 和 `opi5p` 的认证请求均返回 `200`；同一 URL
的匿名请求返回 `401`。2026-08-12 后只有 `ml-builder` 存在
`/run/secrets/attic-upload-key`。

在 greencloud-jp 上：

```bash
systemctl is-active atticd nginx postgresql
journalctl -u atticd.service --since '30 minutes ago' --no-pager
```

缓存配置和权限需要管理员 token 时，使用 `attic cache info zhyi` 检查；不要为了
修改优先级或 upstream key 直接更新 PostgreSQL 表。

## 从公开缓存切换为私有缓存（已完成）

必须严格按以下顺序操作，避免所有主机同时失去 substituter：

1. 在 `volcengine` 生成长期只读 token，仅授予 `--pull zhyi`。
2. 将其以上述 netrc 格式写入 secrets 仓库的 `common/nix.yaml` 中
   `nix-netrc` 字段；不要把 JWT 输出到终端日志或 Shell history。
3. 更新主仓库的 `secrets` flake input，先部署全部受管主机。
4. 在至少 `ml-builder` 和一台普通客户端验证带认证的
   `nix-cache-info` 及一次真实 substitution。
5. 使用临时管理 token 登录 Attic，然后执行：

   ```bash
   attic cache configure zhyi --private
   ```

   当前 `attic-client 0.1.0` 在仅传 `--private` 时也会发送
   `retention_period = Global`，所以临时 token 实际需要同时具有
   `--pull zhyi`、`--configure-cache zhyi` 和
   `--configure-cache-retention zhyi`。这不会改变当前缓存策略，因为
   `zhyi` 沿用服务端全局的 3 个月 retention。临时 token 不需要且不应
   具有 push、delete、create-cache 或 destroy-cache。

6. 验证匿名请求返回 `401` 或 `403`，而配置了 netrc 的 Nix 请求仍成功：

   ```bash
   curl -o /dev/null -sS -w '%{http_code}\n' \
     https://attic.zhyi.xin/zhyi/nix-cache-info
   curl --fail --netrc-file /run/secrets/nix-netrc \
     https://attic.zhyi.xin/zhyi/nix-cache-info
   ```

不要直接修改 PostgreSQL 的 `cache.is_public`。使用 Attic API 可以保留权限检查和
兼容性；也不要执行 `--regenerate-keypair`，私有化不需要更换缓存签名密钥。

更新 `common/nix.yaml` 后必须更新主仓库的 `secrets` lock 并部署主机；直接覆盖
`/run/secrets/nix-netrc` 只能作为在线热修，重启后会丢失：

```bash
cd /nix/src/nixos-config
git pull --ff-only
make all
```

## 缓存优先级与容量判断

自有 Attic 优先、是否完整镜像上游缓存、以及 S3 占用大小是三件不同的事。

### 优先级

Nix 依据 binary cache 的 `Priority` 选择下载源，数值越小优先级越高。配置
`substituters` 的排列顺序不能替代服务端优先级。

```bash
attic cache info zhyi
curl -fsS https://attic.zhyi.xin/zhyi/nix-cache-info
```

只有持有 `configure_cache` 权限的管理员才可以修改 priority。修改前后都必须记录
`attic cache info` 的输出；不要绕过 Attic CLI 直接写 PostgreSQL。

### 上游缓存与独立性

若 Attic cache 配置了 `upstream-cache-key-names`，`attic push` 可能显示
`in upstream`，表示已被信任的上游签名覆盖而跳过上传。这能节约自身 S3 空间，但不
代表自有 S3 保存了完整闭包。

若目标是离线/独立可恢复的闭包缓存，应由管理员将 upstream key 列表设为空，并在
目标系统闭包上重跑补推；不能扫描或盲推整块 `/nix/store` 来代替闭包验收。

### 容量判断

`nix path-info -Sh` 给出的 NAR 大小是未压缩值。Attic 当前使用 zstd 压缩，并会共享
重复对象，因此 S3 bucket 的实际占用通常明显更小。完整性应以以下证据判断：

1. 目标系统 root 的闭包路径都可由 Attic 下载。
2. 第二次 `attic push` 不再有待上传路径。
3. 新机器只启用 Attic 时可以复制该闭包或完成安装。

出现 502 或网络中断后，可以重复相同的定向 `attic push`；已完成对象会去重。先检查
Attic 与反代日志，不要因单个错误就清空数据库或 S3。

## 上传

`ml-builder` 的 Hydra 会自动登录并上传，同一主机也保留手动上传凭据，不启用
`attic-watch-store`；这与作者默认不在构建机持续监视整个 Nix store 的做法一致。
手动上传：

```bash
attic login --set-default zhyi https://attic.zhyi.xin \
  "$(cat /run/secrets/attic-upload-key)"
attic push zhyi ./result
```

`attic-upload-key` 应只具有 `--pull zhyi --push zhyi`，不应带
`create-cache`、`configure-cache`、`destroy-cache` 或 `delete` 权限。完成私有化后，
管理员 token 不应保留在构建机上。

### 手动补推流程

日常构建由 Hydra 的 post-build hook 上传。只有新增系统、补齐明确缺失的闭包，或
确认缓存写入中断时才手动补推。不要把“全量推送”理解为扫描并上传整块
`/nix/store`：这会包含无关历史路径，也会放大并发上传问题。

1. **构建并固定目标闭包**（在 `ml-builder` 上，用 out-link 保留系统根）：

   ```bash
   cd /nix/src/nixos-config
   HOST=rock5c
   nix build ".#nixosConfigurations.$HOST.config.system.build.toplevel" \
     --out-link "/root/cache-roots/$HOST"
   ```

   需要构建 `hosts/` 中的完整自有 Hive 时用 `make build`（不会切换任何机器）。

2. **定向上传**（token 由 SOPS 提供，不能打印或写入 shell 历史）：

   ```bash
   ROOT=/root/cache-roots/rock5c
   TOKEN=$(cat /run/secrets/attic-upload-key)
   nix shell nixpkgs#attic-client -c attic login --set-default zhyi \
     https://attic.zhyi.xin "$TOKEN"
   nix shell nixpkgs#attic-client -c attic push zhyi "$ROOT"
   ```

   需要补推 `.gcroots` 中的多个已验证根时用 `make push-cache`。不要启用
   `attic-watch-store` 来替代这一步；当前 `ml-builder` 明确没有启用该服务。

3. **验收与重试**：

   ```bash
   P=$(readlink -f "$ROOT")
   nix copy --from https://attic.zhyi.xin/zhyi \
     --to file:///tmp/attic-copy-test "$P"
   rm -rf /tmp/attic-copy-test
   ```

   网络错误或 HTTP 502 后先检查服务端：

   ```bash
   ssh -A -p 2222 root@greencloud.zhyi.xin \
     'systemctl status atticd.service --no-pager -l; journalctl -u atticd.service -n 100 --no-pager'
   ```

   确认服务正常后重新执行完全相同的定向上传。已成功对象会显示为已缓存，不会因中断
   整体损坏。

4. **不要直接清库**：删除 S3 对象、截断 Attic 表、重建 cache 或轮换 cache key
   都是事故恢复操作，必须先备份 PostgreSQL、确认所有客户端的公钥迁移方案，并单独
   记录变更。客户端出现旧 narinfo 或本地 store 损坏时，先分别验证目标路径、Attic
   narinfo 和服务端日志，不要把问题扩大成整库清理。

## S3 与流量边界

Attic 负责 narinfo、鉴权与对象索引；已发布 NAR 由 S3 后端提供。S3 bucket 不向
客户端公开写入，客户端始终使用 Attic URL。Attic 的 GC 由服务端每 12 小时执行，
默认保留期为 3 个月；不要在 S3 侧另设会删除仍被 Attic 引用对象的生命周期规则。

缓存损坏、旧 narinfo 或需要补推闭包时，先按
[补推流程](#手动补推流程) 核对服务端、目标闭包和客户端的
`nix-cache-info`，不要直接删除对象或数据库记录。
