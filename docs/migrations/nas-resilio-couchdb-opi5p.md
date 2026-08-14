# QNAP NAS 容器迁移到 OPI5P（couchdb / resilio-sync，2026-08）

把 QNAP Container Station（`192.168.0.40`）上 Docker 运行的两个服务迁移到
opi5p 原生 Nix 服务，按"原生 Nix 包优先"约定不再依赖 QNAP Docker。

## 迁移范围

| 服务 | NAS 容器 | 数据量 | opi5p 落位 |
| --- | --- | --- | --- |
| couchdb-obsidian-livesync | `couchdb:3.5.1`，`:5984` | 2.8G | nixpkgs `couchdb3` 3.5.1 + `services.couchdb` |
| resilio-sync | `lscr.io/linuxserver/resilio-sync`，`:8888` UI / `:55555` 同步 | 配置 2G + 数据 358G | nixpkgs `resilio-sync` 3.1.1.1075 + 自建 systemd 服务 |

不迁移（留在 NAS）：`proxmox-backup-server`（已停止）、`qnap-k3s`、`mt-photos`。

## 包来源结论（2026-08-14 验证）

- `couchdb`：nixpkgs 有包（`couchdb3`，版本与 NAS 容器一致）和 `services.couchdb` 模块。
- `resilio-sync`：nixpkgs 有包（unfree，`allowUnfree` 已由 xddxdd nixpkgs-options
  模块默认开启），但全 GitHub/NUR 无 NixOS 模块，在 `nixos/optional-apps/` 自建。

## 迁移后拓扑

- couchdb：opi5p 原生 systemd，监听 `0.0.0.0:5984`（`LT.port.CouchDB`）
  - 数据：`/mnt/storage/couchdb/data`（NFS → QNAP `/share/CACHEDEV1_DATA/nixos/couchdb/data`）
  - 视图索引：`/var/lib/couchdb`（本地 NVMe，可重建）
  - admin：统一口令 `default-pw` 的 pbkdf2 哈希，经 sops（`nixos-secrets/couchdb.yaml`）
  - 原 `local.d` 配置（uuid、CORS、`max_document_size` 等）复刻到
    `hosts/opi5p/home-services.nix` 的 `services.couchdb.extraConfig`
- resilio-sync：opi5p 原生 systemd `resilio.service`
  - 身份/配置：`/var/lib/resilio-sync`（本地持久化；备份排除 `*.db` 规则已存在）
  - 同步数据：`/mnt/storage/resilio/data`（NFS），bind 到 `/sync`；
    `downloads` 目录 bind 到 `/downloads`（原数据库内路径硬编码 `/sync/...`，
    用 bind 保持零改动）
  - webui 监听沿用迁移配置 `0.0.0.0:8888`（LAN 内访问）
- 入口不变：`couchdb.zhyi.xin`（CNAME → home DDNS）→ rock5c nginx →
  opi5p:5984（`hosts/rock5c/home-lan-edge.nix` 改 proxyPass，DNS 记录不动）

## 数据迁移步骤（停机窗口执行，全量 358G）

1. `docker stop couchdb-obsidian-livesync resilio-sync`（QNAP）
2. QNAP 本地复制（同盘不打网络）：
   - `/share/Container/couchdb/data` → `/share/CACHEDEV1_DATA/nixos/couchdb/data`
   - `/share/Container/resilio/*` → `/share/CACHEDEV1_DATA/nixos/resilio/`
3. opi5p：resilio 配置目录 `mv` 到 `/var/lib/resilio-sync`（本地 2G）；
   数据目录 chown 到 `couchdb` / `resilio-sync` 用户（NFS `no_root_squash`）
4. 构建（ml-builder）→ 部署 opi5p + rock5c → 启动验证

## 验证

- couchdb：`_up`、`_all_dbs`、admin 认证、经 `https://couchdb.zhyi.xin/_up` 验证
- resilio：webui `:8888` 登录、`systemctl status resilio`、同步文件夹状态

## 回滚

- QNAP 容器保持停止、未删除，原数据仍在 `/share/Container/`
- 回滚：停止 opi5p 服务 → 启动 QNAP 容器 → rock5c proxyPass 指回 `192.168.0.40:5984`

## 客户端影响

- Obsidian Livesync 各设备：迁移后需在插件设置里更新统一口令（`default-pw`）
- Resilio 各设备：身份/端口不变，自动重连；无配置改动

## 待办

- Obsidian 客户端口令更新
- resilio webui 本地账号口令可选统一为 `default-pw`（webui 内改）
- 稳定 1-3 天后清理 NAS 侧 `/share/Container/{couchdb,resilio}` 原数据（需用户确认）
