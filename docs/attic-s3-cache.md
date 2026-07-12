# 自建作者同款 Attic + S3 构建缓存

本文目标是复刻原作者的缓存思路，但换成自己的基础设施。

原作者路线大概是：

```text
Hydra / builder 构建
  -> attic push
  -> Attic server
  -> S3-compatible storage
  -> NixOS 机器从 Attic 拉 binary cache
```


你可以先不搭 Hydra，先用自己的强机器、NixOS 虚拟机、GitHub self-hosted runner 构建，然后手动或自动 `attic push`。等缓存链路跑通后，再考虑 Hydra。

## 1. 仓库里原作者怎么做

Attic 服务端在：

```text
nixos/optional-apps/attic.nix
```

关键配置：

```nix
services.atticd = {
  enable = true;
  mode = "monolithic";
  settings = {
    database.url = "postgres://atticd?host=/run/postgresql&user=atticd";
    storage = {
      type = "s3";
      region = "us-central-1";
      bucket = "lantian-nix-cache";
      endpoint = "https://us-central-1.telnyxstorage.com";
    };
  };
};
```

Hydra 构建成功后推缓存的位置：

```text
nixos/optional-apps/hydra/post-build.py
```

关键逻辑：

```python
["attic", "push", "lantian", *output_paths]
```

还有一个可选的自动上传 store 服务：

```text
nixos/optional-apps/attic-watch-store.nix
```

核心命令：

```bash
attic watch-store lantian
```

所以作者不是让每台机器自己编，而是：

```text
构建机编译 -> Attic 收产物 -> 其他机器下载
```

## 2. 你的自建目标

你有自己的 HTTPS path-style S3 服务，可以这样设计：

```text
S3 服务
  endpoint = https://rustfs.zhyi.cc:4000
  bucket   = nix-cache
  path     = https://rustfs.zhyi.cc:4000/nix-cache/...

Attic server
  https://attic.zhyi.xin:8443
  连接 PostgreSQL
  连接 S3 bucket

Builder
  nix build
  attic push nixos ./result closure

ml-2700u
  substituter = https://attic.zhyi.xin:8443/nixos
```

这里 `nixos` 是 Attic cache 名字，可以换成你喜欢的名字。

## 3. path-style S3 怎么配

Attic 的 S3 配置不需要单独写 `path-style = true`。

Attic 使用 AWS SDK。只要你配置了自定义：

```nix
endpoint = "https://rustfs.zhyi.cc:4000";
```

它就会使用 path-style 访问方式，形态类似：

```text
https://rustfs.zhyi.cc:4000/<bucket>/<object-key>
```

这正适合 MinIO、NAS S3、很多自建 S3-compatible 服务。

## 4. S3 侧准备

在你的 S3 服务里准备：

```text
bucket: nix-cache
endpoint: https://rustfs.zhyi.cc:4000
region: us-east-1
access key: <ATTIC_S3_ACCESS_KEY>I7NEK6WsfjtiWoCiLKan
secret key: <ATTIC_S3_SECRET_KEY>04AnPosCQf9wJhZXLHQQ69IqGmoBgY3MMu20fk7x
```

建议：

- bucket 不公开写入。
- access key 只给这个 bucket 的读写权限。
- 如果 S3 服务支持 lifecycle，可以配置旧对象清理。
- 先不要把 S3 直接暴露给 Nix 客户端，先让 Attic 作为唯一入口。

## 5. Attic 服务端 NixOS 配置

可以新建一个自己的模块，例如：

```text
nixos/optional-apps/my-attic.nix
```

基础版本：

```nix
{
  config,
  lib,
  pkgs,
  ...
}:
{
  services.postgresql = {
    enable = true;
    ensureDatabases = [ "atticd" ];
    ensureUsers = [
      {
        name = "atticd";
        ensureDBOwnership = true;
      }
    ];
  };

  users.users.atticd = {
    isSystemUser = true;
    group = "atticd";
  };
  users.groups.atticd = { };

  services.atticd = {
    enable = true;
    package = pkgs.attic-server;
    mode = "monolithic";

    # 推荐用 sops-nix 或 systemd credential 管理这个文件。
    environmentFile = "/run/secrets/attic-env";

    settings = {
      listen = "127.0.0.1:8080";
      api-endpoint = "https://attic.example.com/";
      substituter-endpoint = "https://attic.example.com/";

      database = {
        url = "postgres://atticd?host=/run/postgresql&user=atticd";
        heartbeat = true;
      };

      require-proof-of-possession = false;

      storage = {
        type = "s3";
        region = "us-east-1";
        bucket = "nix-cache";
        endpoint = "https://s3.example.com";
      };

      # 先照搬作者思路：关闭 chunking，方便 S3 直接下载完整 NAR。
      chunking = {
        nar-size-threshold = 0;
        min-size = 16384;
        avg-size = 65536;
        max-size = 262144;
      };

      compression = {
        type = "zstd";
        level = 9;
      };

      garbage-collection = {
        interval = "12 hours";
        default-retention-period = "3 month";
      };
    };
  };

  services.nginx = {
    enable = true;
    virtualHosts."attic.example.com" = {
      forceSSL = true;
      enableACME = true;
      locations."/" = {
        proxyPass = "http://127.0.0.1:8080";
        proxyWebsockets = true;
        extraConfig = ''
          proxy_read_timeout 3600s;
          proxy_send_timeout 3600s;
          client_max_body_size 0;
        '';
      };
    };
  };
}
```

`/run/secrets/attic-env` 至少需要这些环境变量：

```bash
AWS_ACCESS_KEY_ID=你的S3AccessKey
AWS_SECRET_ACCESS_KEY=你的S3SecretKey
ATTIC_SERVER_TOKEN_HS256_SECRET_BASE64=一段base64随机密钥
```

生成 HMAC secret：

```bash
openssl rand -base64 64
```

如果你用 sops-nix，建议把这三个值放进 secrets 仓库，不要提交明文。

## 6. 初始化 Attic cache

在能访问 Attic server 的机器上：

```bash
export NIX_CONFIG="experimental-features = nix-command flakes"
nix shell nixpkgs#attic-client -c bash
```

登录。第一次可以用 root/admin token，具体 token 取决于你怎么初始化 Attic：

```bash
attic login local https://attic.example.com <admin-or-root-token>
```

创建 cache：

```bash
attic cache create nixos
attic cache configure nixos --public
```

生成给 builder 用的 push token：

```bash
atticadm make-token --sub builder --validity "1 year" --pull nixos --push nixos
```

查看客户端配置：

```bash
attic use nixos
```

会输出类似：

```text
extra-substituters = https://attic.example.com/nixos
extra-trusted-public-keys = nixos:xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx=
```

## 7. Builder 推缓存

强机器或 NixOS 虚拟机构建完成后：

```bash
cd /root/nixos-config
nix build .#nixosConfigurations.ml-2700u.config.system.build.toplevel -L \
  --option max-jobs 2 \
  --option cores 6
```

登录 Attic：

```bash
attic login local https://attic.example.com <builder-push-token>
```

推完整 closure：

```bash
attic push nixos $(nix path-info -r ./result)
```

以后也可以推当前系统：

```bash
attic push nixos $(nix path-info -r /run/current-system)
```

## 8. 让 ml-2700u 使用缓存

把 `attic use nixos` 输出写进 `ml-2700u` 配置：

```nix
{
  nix.settings.substituters = [
    "https://attic.example.com/nixos"
    "https://cache.nixos.org"
  ];

  nix.settings.trusted-public-keys = [
    "nixos:xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx="
  ];
}
```

然后：

```bash
cd /etc/nixos
export NIX_CONFIG="experimental-features = nix-command flakes"
nixos-rebuild switch --flake .#ml-2700u -L
```

命中缓存时应该大量看到：

```text
copying path
```

而不是：

```text
building
```

## 9. 最小上线顺序

建议按这个顺序来：

1. S3 bucket 建好，确认 access key 能读写。
2. Attic server 连接 PostgreSQL 和 S3。
3. Nginx/HTTPS 暴露 `https://attic.example.com`。
4. 创建 `nixos` cache。
5. 生成 builder push token。
6. builder 构建 `ml-2700u` 并 `attic push`。
7. `ml-2700u` 加入 substituter 和 public key。
8. 重新 build，确认从 `building` 变成 `copying path`。

## 10. 常见坑

### S3 path-style 访问失败

确认 Attic 配置里写了：

```nix
endpoint = "https://s3.example.com";
```

有自定义 endpoint 时，Attic 会走 path-style。不要写成 bucket virtual-host 风格的 endpoint。

### push 很慢

第一次推 KDE client 闭包可能几十 GB，很正常。先推一次完整 closure，后面只会补新增 store path。

### 客户端仍然 building

通常是下面几种：

- `ml-2700u` 没配 `trusted-public-keys`。
- builder 构建的 flake 和 `ml-2700u` 当前 flake 不一致。
- builder 没把完整 closure 推上去。
- Attic cache 不是 public，客户端无权限读取。

### S3 账单暴涨

Nix cache 会吃容量和出站流量。建议：

- 先只在内网测试。
- 给 bucket 配 lifecycle。
- Attic 配 garbage collection。
- 不要一开始公开给所有机器乱拉。

