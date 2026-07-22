# Attic + S3 缓存架构

当前缓存名、公开端点与公钥只以
[`helpers/constants/nix.nix`](../helpers/constants/nix.nix) 为准。不要在文档、Shell
历史或 Git 提交中复制上传 token、S3 access key、S3 secret key 或 Attic 私钥。

## 当前结构

```text
Hydra (pve-5700u) / 手动构建 (ml-builder)
  -> attic push lantian
  -> Attic (cnvm)
  -> PostgreSQL + VaultS3 (home-ddns) bucket nix-cache
  -> Nix clients
```

- Attic 服务、Nginx vhost 与 S3 参数定义在
  [`nixos/optional-apps/attic.nix`](../nixos/optional-apps/attic.nix)，由
  `hosts/cnvm/configuration.nix` 导入。
- Attic 只监听回环地址，由同机 Nginx 发布；外部数据面使用
  `https://attic.zhyi.xin/lantian`（标准 443 端口）。
- S3 凭据与上传 token 只在私有 secrets 仓库的 `common/attic.yaml` 中以 SOPS 加密
  保存。修改它必须遵循 secrets 仓库的 `docs/sops-manual.md`。
- Hydra 在
  [`nixos/optional-apps/hydra/default.nix`](../nixos/optional-apps/hydra/default.nix)
  中通过 post-build hook 上传成功构建的输出。不要同时在多台机器启用
  `attic-watch-store`，否则会制造重复上传和难以判断的失败日志。

## 客户端使用

客户端的默认 substituter 与公钥由 `LT.nix.attic` 统一提供。NCPS 客户端先请求
Attic，再回退到本机 NCPS；该顺序定义在
[`nixos/optional-apps/ncps-client.nix`](../nixos/optional-apps/ncps-client.nix)。

安装环境或临时 shell 不应手写长期 `/etc/nix/nix.conf`。仅在尚未加载目标配置时，
从 `helpers/constants/nix.nix` 读取当前 URL 和公钥后，以一次性的 `NIX_CONFIG` 传入。

## 健康检查

在任意已配置客户端上：

```bash
curl -fsS https://attic.zhyi.xin/lantian/nix-cache-info
nix store ping --store https://attic.zhyi.xin/lantian
```

在 cnvm 上：

```bash
systemctl is-active atticd nginx postgresql
journalctl -u atticd.service --since '30 minutes ago' --no-pager
```

缓存配置和权限需要管理员 token 时，使用 `attic cache info lantian` 检查；不要为了
修改优先级或 upstream key 直接更新 PostgreSQL 表。

## S3 与流量边界

Attic 负责 narinfo、鉴权与对象索引；已发布 NAR 由 S3 后端提供。S3 bucket 不向
客户端公开写入，客户端始终使用 Attic URL。Attic 的 GC 由服务端每 12 小时执行，
默认保留期为 3 个月；不要在 S3 侧另设会删除仍被 Attic 引用对象的生命周期规则。

缓存损坏、旧 narinfo 或需要补推闭包时，先按
[补推流程](./attic-full-store-push.md) 核对服务端、目标闭包和客户端的
`nix-cache-info`，不要直接删除对象或数据库记录。
