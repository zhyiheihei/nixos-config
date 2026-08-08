# VaultS3 迁移到 Router（2026-08-07）

把 QNAP Container Station 上 Docker 运行的 `eniz1806/vaults3`（4.4.27）迁移到
router 原生 VaultS3 4.4.49（来自 `zhyi-packages` 的 arm64 官方发布二进制）。
按“原生 Nix 包优先”的约定，不继续依赖 QNAP Docker。

## 迁移后拓扑

- vaults3 服务：router 原生 systemd，监听 `0.0.0.0:9000`
- 数据目录：`/mnt/storage/vaults3-data`（NFS → QNAP
  `/share/CACHEDEV1_DATA/nixos/vaults3-data`）
- 元数据：`/nix/persistent/var/lib/vaults3`（router NVMe，避免 BoltDB 跨 NFS）
- 入口不变：router DNAT 8443 → opi5p:443 nginx → router:9000
  （`vaults3.zhyi.cc` 保持原域名）

## 验证

- 复制并校验：200,162 个文件，`vaults3.db` sha256 与源一致
- `vaults3.service` active，`/health` ok
- `vaults3-cli bucket list`：`1panel`、`gitea`、`nix-cache`、`rustic-backup`；
  `nix-cache` 对象数 199,686
- 公网 `https://vaults3.zhyi.cc:8443/health` 返回 200
- Attic narinfo 读取 200；受控小对象上传成功，narinfo 200
- atticd 迁移后 10 分钟内 0 条 storage error

## 回滚

- QNAP 容器保持停止、未删除，原数据仍在
  `/share/CACHEDEV1_DATA/Container/vaults3`
- 回滚步骤：停止 router `vaults3.service` → 启动 QNAP 容器 →
  将 opi5p nginx 上游指回 `192.168.0.40:9000`

## 待办

- `hydra-attic-repush` 在迁移窗口前已停止，需要时再恢复
- 旧 MinIO 数据（`Container/minio`）与本次迁移无关，未改动

## 升级到 4.4.50（2026-08-08）

- `zhyi-packages` 更新到 `3d6dd08`，VaultS3 由 4.4.49 升到官方 4.4.50。
- 官方 4.4.50 修复了高并发 multipart 上传问题（Issue 48，
  `internal/s3/multipart.go`），对应 Attic 大闭包并发 part 上传时的 403/404 风暴。
- GitHub 地址不需要更换：`zhyi-packages` 的 nvfetcher 已指向
  `Kodiqa-Solutions/VaultS3`。
- 升级/重启 VaultS3 时若 atticd 正在上传，旧 multipart 会话会失效并持续返回
  `NoSuchUpload` 404；升级后应重启 `atticd` 丢弃失效会话，并清理空
  `.multipart` 目录（2026-08-08 已按此处理）。

## 统一账户密码（2026-08-08）

- VaultS3 管理凭据改为统一约定：账号 `zhyi`，密码来自
  `common/default-pw.yaml`。`hosts/router/vaults3.nix` 通过
  `sops.templates.vaults3-credentials` 生成 `VAULTS3_ACCESS_KEY=zhyi` 与
  `VAULTS3_SECRET_KEY=<default-pw>`。
- 修改 `common/default-pw.yaml` 并切换 router 即可自动轮换，不再维护独立的
  `common/vaults3.yaml`（该文件已删除）。
- 验证命令（不会输出密码值）：

  ```bash
  VAULTS3_ACCESS_KEY=zhyi \
  VAULTS3_SECRET_KEY="$(cat /run/secrets/default-pw)" \
    /nix/store/*vaults3*/bin/vaults3-cli info
  ```
