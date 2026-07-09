# Attic 手动补推缓存流程

本文只记录当前已经验证过的一条流程：当 Attic 缓存出现 DB/S3 不一致，或需要重新补齐某台机器的系统闭包时，在缓存机清理 Attic 对象索引，然后在强机器重新构建并推送目标闭包。

当前缓存地址：

```text
https://attic.zhyi.cc:4000/lantian
```

当前 public key：

```text
lantian:Pi7qMC8lIOrR8cTh4vfcRuSL/z+Bh5BAFYlEo/mbq2U=
```

## 1. 清理 Attic 对象索引

在缓存机执行：

```bash
ssh -A -p 2222 root@192.168.2.135
```

备份数据库，并清掉旧 object/nar/chunk 索引：

```bash
backup=/var/lib/atticd/atticd-before-cache-index-reset-$(date +%Y%m%d-%H%M%S).sql

systemctl stop atticd.service
sudo -u postgres pg_dump atticd > "$backup"
sudo -u postgres psql -d atticd -v ON_ERROR_STOP=1 \
  -c "TRUNCATE TABLE object, chunkref, nar, chunk RESTART IDENTITY CASCADE;"
systemctl start atticd.service
systemctl is-active atticd.service

echo "$backup"
```

这一步保留 `lantian` cache 名称、public key 和服务配置，只让后续 push 重新生成正确的 narinfo 和 S3 对象关系。

## 2. 在强机器构建目标系统

到强机器执行。以 `ml-2700u` 为例：

```bash
ssh -A -p 2222 root@192.168.3.192
cd /nix/src/nixos-config

nix build .#nixosConfigurations.ml-2700u.config.system.build.toplevel \
  --out-link /tmp/ml-2700u-result
```

如果换成别的 host，只改 host 名和 out-link：

```bash
HOST=ml-builder-cache
nix build .#nixosConfigurations.${HOST}.config.system.build.toplevel \
  --out-link /tmp/${HOST}-result
```

## 3. 推送目标闭包到 Attic

仍然在强机器执行：

```bash
TOKEN=$(cat /run/secrets/attic-upload-key)

nix shell nixpkgs#attic-client -c attic login --set-default lantian \
  https://attic.zhyi.cc:4000 "$TOKEN"

nix shell nixpkgs#attic-client -c attic push lantian /tmp/ml-2700u-result

#全量推送
ssh -A -p 2222 root@ml-builder
cd /nix/src/nixos-config

TOKEN=$(cat /run/secrets/attic-upload-key)

nix shell nixpkgs#attic-client -c attic login --set-default lantian \
  https://attic.zhyi.cc:4000 "$TOKEN"

nix path-info --all | xargs -r -n 200 nix shell nixpkgs#attic-client -c attic push lantian

```

如果上一步用了 `HOST` 变量：

```bash
nix shell nixpkgs#attic-client -c attic push lantian /tmp/${HOST}-result
```

看到大量类似输出就是正常：

```text
✅ <store-path-name> (... KiB/s)
✅ <store-path-name> (deduplicated)
```

如果出现少量 `HTTP 502 Bad Gateway`，等命令结束后重新执行同一条 `attic push`。

## 4. 抽样验证

推完后，任选一个刚才失败过或关心的 store path，验证 Attic 真的能把 NAR 拉下来：

```bash
P=/nix/store/<hash-name>
rm -rf /tmp/attic-copy-test

nix copy \
  --from https://attic.zhyi.cc:4000/lantian \
  --to file:///tmp/attic-copy-test \
  "$P"
```

这个命令成功，才说明 narinfo 和 S3 里的 `nar/*.nar` 都是可用的。

## 5. 安装机使用缓存

安装机里使用正确 key，例如：

```bash
env NIX_CONFIG='experimental-features = nix-command flakes
accept-flake-config = true
substituters = https://cache.nixos.org https://attic.zhyi.cc:4000/lantian
trusted-public-keys = cache.nixos.org-1:6NCHdD59X431o0gWJ0qOeuKX2w8VxlNjY36Heq3v4F4= lantian:Pi7qMC8lIOrR8cTh4vfcRuSL/z+Bh5BAFYlEo/mbq2U=
max-jobs = 0
fallback = true' \
  nixos-install --flake path:/mnt/etc/nixos#ml-2700u --no-root-passwd --no-channel-copy
```

`max-jobs = 0` 用来确认弱机器只拉缓存、不本地编译。若闭包没推完整，它会失败暴露问题。
