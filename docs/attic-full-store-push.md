# Attic 手动补推缓存流程

日常构建由 Hydra 的 post-build hook 上传。只有新增系统、补齐明确缺失的闭包，或
确认缓存写入中断时才手动补推。不要把“全量推送”理解为扫描并上传整块
`/nix/store`：这会包含无关历史路径，也会放大并发上传问题。

## 1. 构建并固定目标闭包

在 `ml-builder` 上运行。使用明确的 out-link 或 `.gcroots` 保留要上传的系统根：

```bash
cd /nix/src/nixos-config
HOST=ml-home-vm
nix build ".#nixosConfigurations.$HOST.config.system.build.toplevel" \
  --out-link "/root/cache-roots/$HOST"
```

需要构建 `hosts/` 中的完整自有 Hive 时，可使用 `make build`。它不会切换任何机器。

## 2. 定向上传

上传 token 由 SOPS 提供，不能打印或写入 shell 历史。若当前机器已配置
`attic-upload-key`，使用：

```bash
ROOT=/root/cache-roots/ml-home-vm
TOKEN=$(cat /run/secrets/attic-upload-key)

nix shell nixpkgs#attic-client -c attic login --set-default lantian \
  https://attic.zhyi.xin:8443 "$TOKEN"
nix shell nixpkgs#attic-client -c attic push lantian "$ROOT"
```

需要补推 `.gcroots` 中的多个已经验证根时，使用现有 Makefile 目标：

```bash
make push-cache
```

不要启用 `attic-watch-store` 来替代这一步；当前 `ml-builder` 和 `ml-home-vm` 都明确
没有启用该服务。

## 3. 验收与重试

```bash
P=$(readlink -f "$ROOT")
nix copy --from https://attic.zhyi.xin:8443/lantian \
  --to file:///tmp/attic-copy-test "$P"
rm -rf /tmp/attic-copy-test
```

网络错误或 HTTP 502 后，先检查服务端：

```bash
ssh -A -p 2222 root@colocrossing.zhyi.cc \
  'systemctl status atticd.service --no-pager -l; journalctl -u atticd.service -n 100 --no-pager'
```

确认服务正常后重新执行完全相同的定向上传。已成功对象会显示为已缓存，不会因中断
整体损坏。

## 4. 不要直接清库

删除 S3 对象、截断 Attic 表、重建 cache 或轮换 cache key 都是事故恢复操作，必须先
备份 PostgreSQL、确认所有客户端的公钥迁移方案，并单独记录变更。客户端出现旧
narinfo 或本地 store 损坏时，先分别验证目标路径、Attic narinfo 和服务端日志，
不要把问题扩大成整库清理。
