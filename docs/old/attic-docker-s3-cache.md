# Docker 部署 Attic 并使用 Garage S3

本文是 [`attic-s3-cache.md`](../attic-s3-cache.md) 的临时落地版：现在还没有合适的 NixOS server，所以先在一台普通 Docker 机器上跑 Attic server，后端对象存储使用已经通过 Caddy 反代验证过的 Garage S3。

目标链路：

```text
builder / laptop / CI
  -> attic push
  -> https://attic.zhyi.cc:4000
  -> Caddy
  -> Docker Attic server
  -> PostgreSQL metadata
  -> Garage S3 object storage
```

已验证可用的 S3 入口：

```text
endpoint = https://s3-garage.zhyi.cc:4000
region   = garage
```

建议新建专用 bucket：

```text
nix-cache
```

不要把 S3 access key、secret key、Attic token、PostgreSQL 密码提交到 git。

## 1. 目录规划

在 Docker 服务器上准备目录：

```bash
mkdir -p /srv/attic
mkdir -p /srv/attic/config
mkdir -p /srv/attic/env
cd /srv/attic
```

本文假设：

- Docker server 内部监听 `0.0.0.0:8080`。
- Caddy 对外域名是 `attic.zhyi.cc`。
- 你当前公网 HTTPS 走 `:4000`，所以外部 Attic URL 暂用 `https://attic.zhyi.cc:4000`。
- 如果以后路由器把公网 443 直接转发给 Caddy，再把 URL 改成 `https://attic.zhyi.cc`。

## 2. 准备 S3 bucket

先用临时 S3 客户端创建 bucket。这里用 `rclone` 举例：

```bash
export AWS_ACCESS_KEY_ID="你的 Garage access key"
export AWS_SECRET_ACCESS_KEY="你的 Garage secret key"

rclone mkdir :s3:nix-cache \
  --s3-provider Other \
  --s3-env-auth \
  --s3-endpoint https://s3-garage.zhyi.cc:4000 \
  --s3-region garage \
  --s3-force-path-style
```

确认能写入再删除测试对象：

```bash
printf "attic s3 test\n" | rclone rcat :s3:nix-cache/attic-s3-test.txt \
  --s3-provider Other \
  --s3-env-auth \
  --s3-endpoint https://s3-garage.zhyi.cc:4000 \
  --s3-region garage \
  --s3-force-path-style

rclone cat :s3:nix-cache/attic-s3-test.txt \
  --s3-provider Other \
  --s3-env-auth \
  --s3-endpoint https://s3-garage.zhyi.cc:4000 \
  --s3-region garage \
  --s3-force-path-style

rclone deletefile :s3:nix-cache/attic-s3-test.txt \
  --s3-provider Other \
  --s3-env-auth \
  --s3-endpoint https://s3-garage.zhyi.cc:4000 \
  --s3-region garage \
  --s3-force-path-style
```

## 3. 写 Attic 配置

创建 `/srv/attic/config/server.toml`：

```toml
listen = "[::]:8080"

api-endpoint = "https://attic.zhyi.cc:4000/"
substituter-endpoint = "https://attic.zhyi.cc:4000/"

require-proof-of-possession = false

[database]
url = "postgres://atticd:atticd-password@postgres:5432/atticd"
heartbeat = true

[storage]
type = "s3"
region = "garage"
bucket = "nix-cache"
endpoint = "https://s3-garage.zhyi.cc:5000"

[chunking]
nar-size-threshold = 0
min-size = 16384
avg-size = 65536
max-size = 262144

[compression]
type = "zstd"
level = 9

[garbage-collection]
interval = "12 hours"
default-retention-period = "3 months"
```

把 `atticd-password` 换成下面 `.env` 里的同一个数据库密码。

注意：`server.toml` 里包含数据库连接密码，也不要提交到公开仓库。真正适合入库的是脱敏后的模板，例如 `server.example.toml`。

这里没有在配置文件里写 S3 access key。Attic 使用 AWS SDK 读取环境变量：

```text
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
```

## 4. 写密钥文件

创建 `/srv/attic/env/postgres.env`：

```bash
POSTGRES_DB=atticd
POSTGRES_USER=atticd
POSTGRES_PASSWORD=atticd-password
```

创建 `/srv/attic/env/attic.env`：

```bash
AWS_ACCESS_KEY_ID=replace-me
AWS_SECRET_ACCESS_KEY=replace-me
ATTIC_SERVER_TOKEN_HS256_SECRET_BASE64=replace-me
```

生成 Attic JWT HMAC secret：

```bash
openssl rand -base64 64
```

然后把输出填到：

```text
ATTIC_SERVER_TOKEN_HS256_SECRET_BASE64
```

收紧权限：

```bash
chmod 600 /srv/attic/env/*.env
```

## 5. Dockerfile

Attic 官方文档推荐用 `nix shell github:zhaofengli/attic` 直接运行 `atticd` 做快速试用。为了 Docker 服务启动时不用每次临时拉依赖，这里做一个小镜像，把 Attic 安装进镜像里。

创建 `/srv/attic/Dockerfile`：

```dockerfile
FROM nixos/nix:latest

ARG ATTIC_FLAKE=github:zhaofengli/attic

RUN mkdir -p /etc/nix \
    && printf 'experimental-features = nix-command flakes\n' > /etc/nix/nix.conf \
    && nix profile install "${ATTIC_FLAKE}"

ENV PATH="/root/.nix-profile/bin:${PATH}"

ENTRYPOINT ["atticd"]
```

如果以后要固定 Attic 版本，可以把 `ATTIC_FLAKE` 改成某个 commit：

```bash
docker compose build --build-arg ATTIC_FLAKE=github:zhaofengli/attic/<commit>
```

## 6. Docker Compose

创建 `/srv/attic/compose.yml`：

```yaml
services:
  postgres:
    image: postgres:16-alpine
    container_name: attic-postgres
    restart: unless-stopped
    env_file:
      - ./env/postgres.env
    volumes:
      - postgres-data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U atticd -d atticd"]
      interval: 10s
      timeout: 5s
      retries: 10

  attic:
    build:
      context: .
    container_name: attic
    restart: unless-stopped
    depends_on:
      postgres:
        condition: service_healthy
    env_file:
      - ./env/attic.env
    volumes:
      - ./config/server.toml:/etc/attic/server.toml:ro
    ports:
      - "8080:8080"
    command: ["--config", "/etc/attic/server.toml"]

volumes:
  postgres-data:
```

启动：

```bash
cd /srv/attic
docker compose up -d --build
docker compose logs -f attic
```

第一次启动时，`atticd` 会跑数据库迁移，并在日志里打印 root token 或登录命令。保存这个 root token，不要提交。

## 7. 配 Caddy 反代

在 `caddy-gateway` 仓库的 `Caddyfile` 里，在现有 `*.zhyi.cc` 站点块中加入：

```caddyfile
@attic host attic.zhyi.cc
handle @attic {
	reverse_proxy http://DOCKER_SERVER_LAN_IP:8080 {
		transport http {
			read_timeout 3600s
		}
	}
}
```

如果 Attic 容器和 Caddy 在同一台机器，可以用：

```caddyfile
reverse_proxy http://127.0.0.1:8080
```

部署 Caddy：

```bash
cd /private/tmp/caddy-gateway
./scripts/validate.sh
./scripts/deploy.sh
```

检查公网入口：

```bash
curl -I https://attic.zhyi.cc:5000/
```

没有登录时返回 404、401 或 Attic 的错误响应都不奇怪，关键是响应头里应经过 Caddy，且不是连接失败。

## 8. 初始化 cache

在一台有 Nix 的机器上安装 Attic client：

```bash
nix shell github:zhaofengli/attic -c bash
```

登录：

```bash
attic login local https://attic.zhyi.cc:5000 <root-token>
```

创建 cache：

```bash
attic cache create nixos
attic cache configure nixos --public
```

生成 builder push token：

```bash
atticadm make-token --sub builder --validity "1 year" --pull nixos --push nixos
```

查看 Nix 客户端配置：

```bash
attic use nixos
```

它会输出类似：

```text
extra-substituters = https://attic.zhyi.cc:5000/nixos
extra-trusted-public-keys = nixos:xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx=
```

## 9. Builder 推缓存

在强机器或 Docker builder 上构建完成后：

```bash
cd /root/nixos-config
nix build .#nixosConfigurations.ml-2700u.config.system.build.toplevel -L
```

登录 push token：

```bash
attic login local https://attic.zhyi.cc:5000 <builder-push-token>
```

推完整 closure：

```bash
attic push nixos $(nix path-info -r ./result)
```

如果只是把当前机器已有 store path 推上去：

```bash
attic push nixos $(nix path-info -r /run/current-system)
```

## 10. Nix 客户端使用缓存

把 `attic use nixos` 输出写入 NixOS 配置：

```nix
{
  nix.settings.substituters = [
    "https://attic.zhyi.cc:5000/nixos"
    "https://cache.nixos.org"
  ];

  nix.settings.trusted-public-keys = [
    "nixos:xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx="
  ];
}
```

非 NixOS 机器可以写到 `/etc/nix/nix.conf`：

```text
extra-substituters = https://attic.zhyi.cc:5000/nixos
extra-trusted-public-keys = nixos:xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx=
```

测试命中：

```bash
nix path-info --store https://attic.zhyi.cc:5000/nixos /nix/store/<path>
```

或者重新构建目标系统，观察日志里是否从大量 `building` 变成 `copying path`。

## 11. 运维命令

看日志：

```bash
cd /srv/attic
docker compose logs -f attic
docker compose logs -f postgres
```

重启：

```bash
docker compose restart attic
```

备份 PostgreSQL：

```bash
docker compose exec postgres pg_dump -U atticd atticd > atticd.sql
```

触发一次垃圾回收：

```bash
docker compose run --rm attic --config /etc/attic/server.toml --mode garbage-collector-once
```

升级 Attic 镜像：

```bash
docker compose build --pull attic
docker compose up -d attic
```

## 12. 常见坑

### Attic 访问 S3 报认证失败

优先检查：

- `/srv/attic/env/attic.env` 里的 `AWS_ACCESS_KEY_ID` 和 `AWS_SECRET_ACCESS_KEY`。
- bucket 名是否是 `nix-cache`。
- Attic 容器里能否访问 `https://s3-garage.zhyi.cc:5000`。
- Garage key 是否有这个 bucket 的读写权限。

### 客户端拉缓存仍然 building

常见原因：

- 没有把 `trusted-public-keys` 写到 Nix 配置。
- builder 和客户端使用的 flake 不是同一版。
- 只推了 `./result`，没有推完整 closure。
- cache 没有 `--public`，但客户端又没有配置访问 token。

### 第一次 push 很慢

正常。KDE、浏览器、内核、CUDA 相关 closure 会很大。第一次把基础闭包推完，后面只补增量。

### 数据到底在哪里

PostgreSQL 只保存 Attic 元数据、cache 映射、token 等信息。真正大的 NAR/chunk 对象在 Garage S3 的 `nix-cache` bucket 里。

所以迁移时要同时保留：

- PostgreSQL dump 或 volume。
- Garage S3 bucket 数据。
- `ATTIC_SERVER_TOKEN_HS256_SECRET_BASE64`。

## 13. 以后迁移到 NixOS

等有 NixOS server 后，把本文里的几件事迁移到 NixOS 模块即可：

- `server.toml` 迁移到 `services.atticd.settings`。
- `postgres` 容器迁移到 `services.postgresql`。
- `/srv/attic/env/attic.env` 迁移到 sops-nix 或 systemd credentials。
- Caddy 仍然可以继续作为统一公网入口。

迁移后外部 URL 不变：

```text
https://attic.zhyi.cc:5000/nixos
```

客户端无需重新配置，只要 Attic cache 的 signing key 不变即可。
