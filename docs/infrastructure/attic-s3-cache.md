# 私有 Attic + S3 缓存架构

当前缓存名、公开端点与公钥只以
[`helpers/constants/nix.nix`](../../helpers/constants/nix.nix) 为准。不要在文档、Shell
历史或 Git 提交中复制上传 token、S3 access key、S3 secret key 或 Attic 私钥。

## 当前结构

```text
Hydra (pve-5700u) / 手动构建 (ml-builder)
  -> attic push lantian
  -> Attic (cnvm)
  -> PostgreSQL + VaultS3 (home-ddns) bucket nix-cache
  -> 持有只读 token 的受管 Nix 主机
```

- Attic 服务、Nginx vhost 与 S3 参数定义在
  [`nixos/optional-apps/attic.nix`](../../nixos/optional-apps/attic.nix)，由
  `hosts/cnvm/configuration.nix` 导入。
- Attic 只监听回环地址，由同机 Nginx 发布；外部数据面使用
  `https://attic.zhyi.xin/lantian`（标准 443 端口）。
- `lantian` 已于 2026-07-30 切换为 private；匿名请求返回 `401`，不再提供公开
  substituter。
- S3 凭据与上传 token 只在私有 secrets 仓库的 `common/attic.yaml` 中以 SOPS 加密
  保存。修改它必须遵循 secrets 仓库的 `docs/sops-manual.md`。
- 全体受管主机只通过 `common/nix.yaml` 的 `nix-netrc` 获得 `lantian` 的读取权限。
  上传凭据只部署到 `ml-builder` 和 `pve-5700u`；前者用于手动上传，后者由 Hydra
  自动上传。
- Hydra 在
  [`nixos/optional-apps/hydra/default.nix`](../../nixos/optional-apps/hydra/default.nix)
  中通过 post-build hook 上传成功构建的输出。不要同时在多台机器启用
  `attic-watch-store`，否则会制造重复上传和难以判断的失败日志。

## 权限模型

| 凭据 | 保存位置 | 部署范围 | 权限 |
| --- | --- | --- | --- |
| Attic fleet read token | `common/nix.yaml` 的 `nix-netrc` | 所有受管主机 | 仅 `pull lantian` |
| Attic upload token | `common/attic.yaml` 的 `attic-upload-key` | `ml-builder`、`pve-5700u` | `pull/push lantian` |
| Attic JWT/S3 凭据 | `common/attic.yaml` 的 `attic-credentials` | 仅 `cnvm` 的 `atticd` | 服务端管理与存储 |
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
password <仅含 pull lantian 权限的 JWT>
```

`nixos/minimal-components/nix.nix` 按作者原有模式，通过
`nix.settings.netrc-file` 将该文件交给 Nix。这里必须使用真实换行，不能把 `\n`
两个字符写进 SOPS 字符串。在任意已配置客户端上：

```bash
curl --fail --netrc-file /run/secrets/nix-netrc \
  https://attic.zhyi.xin/lantian/nix-cache-info
```

`nix store ping` 只验证 store URL，不能单独证明私有缓存认证和对象读取成功。
普通 `curl` 也不会自动使用 Nix 的 netrc，因此检查时必须显式指定
`--netrc-file`。

当前已验证 `ml-builder`、`pve-5700u`、`router` 和 `opi5p` 的认证请求均返回
`200`；同一 URL 的匿名请求返回 `401`。其中只有前两台存在
`/run/secrets/attic-upload-key`。

在 cnvm 上：

```bash
systemctl is-active atticd nginx postgresql
journalctl -u atticd.service --since '30 minutes ago' --no-pager
```

缓存配置和权限需要管理员 token 时，使用 `attic cache info lantian` 检查；不要为了
修改优先级或 upstream key 直接更新 PostgreSQL 表。

## 从公开缓存切换为私有缓存（已完成）

必须严格按以下顺序操作，避免所有主机同时失去 substituter：

1. 在 `cnvm` 生成长期只读 token，仅授予 `--pull lantian`。
2. 将其以上述 netrc 格式写入 secrets 仓库的 `common/nix.yaml` 中
   `nix-netrc` 字段；不要把 JWT 输出到终端日志或 Shell history。
3. 更新主仓库的 `secrets` flake input，先部署全部受管主机。
4. 在至少 `ml-builder`、`pve-5700u` 和一台普通客户端验证带认证的
   `nix-cache-info` 及一次真实 substitution。
5. 使用临时管理 token 登录 Attic，然后执行：

   ```bash
   attic cache configure lantian --private
   ```

   当前 `attic-client 0.1.0` 在仅传 `--private` 时也会发送
   `retention_period = Global`，所以临时 token 实际需要同时具有
   `--pull lantian`、`--configure-cache lantian` 和
   `--configure-cache-retention lantian`。这不会改变当前缓存策略，因为
   `lantian` 原本就使用服务端全局的 3 个月 retention。临时 token 不需要且不应
   具有 push、delete、create-cache 或 destroy-cache。

6. 验证匿名请求返回 `401` 或 `403`，而配置了 netrc 的 Nix 请求仍成功：

   ```bash
   curl -o /dev/null -sS -w '%{http_code}\n' \
     https://attic.zhyi.xin/lantian/nix-cache-info
   curl --fail --netrc-file /run/secrets/nix-netrc \
     https://attic.zhyi.xin/lantian/nix-cache-info
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

## 上传

`pve-5700u` 的 Hydra 会自动登录并上传。`ml-builder` 只安装客户端并取得上传
凭据，不启用 `attic-watch-store`；这与作者默认不在构建机持续监视整个 Nix store
的做法一致。手动上传：

```bash
attic login --set-default lantian https://attic.zhyi.xin \
  "$(cat /run/secrets/attic-upload-key)"
attic push lantian ./result
```

`attic-upload-key` 应只具有 `--pull lantian --push lantian`，不应带
`create-cache`、`configure-cache`、`destroy-cache` 或 `delete` 权限。完成私有化后，
管理员 token 不应保留在构建机上。

## S3 与流量边界

Attic 负责 narinfo、鉴权与对象索引；已发布 NAR 由 S3 后端提供。S3 bucket 不向
客户端公开写入，客户端始终使用 Attic URL。Attic 的 GC 由服务端每 12 小时执行，
默认保留期为 3 个月；不要在 S3 侧另设会删除仍被 Attic 引用对象的生命周期规则。

缓存损坏、旧 narinfo 或需要补推闭包时，先按
[补推流程](./attic-full-store-push.md) 核对服务端、目标闭包和客户端的
`nix-cache-info`，不要直接删除对象或数据库记录。
