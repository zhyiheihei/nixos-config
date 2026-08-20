# 知识链同步（Syncthing media 根）规划

状态：四机 mesh 已建成，全绿（errors=0）。

用户确认：完全对齐作者，同步**整个 media 根目录**（含 Secrets），而非 notes 子目录。
用 Syncthing 官方 REST API 做运行时配置，不引入自定义 bindfs / 不手改 config.xml。

## 角色映射

| 角色 | 作者原版 | 我们 |
| --- | --- | --- |
| 主力客户端 | `lt-hp-omen` | `ml-2700` |
| 家庭数据服务器 | `lt-home-vm` | `opi5p` |
| 公网异地节点 | `greencloud` | `greencloud` |
| 物理笔记本 | `lt-dell-wyse` | `ml-laptop` |

作者同步整个 media storage 根（Documents/Books/CloudMusic/Pictures/Secrets/
VideoArchive 全部 bind 到 media 根），storage 默认 `/nix/persistent/media`
（lt-home-vm 为 `/mnt/storage/media`）。我们 1:1 复刻：各机 syncthing.storage 为
- ml-2700 / greencloud / ml-laptop：`/nix/persistent/media`
- opi5p：`/mnt/storage/media`

## 目标

```text
ml-2700   /nix/persistent/media  <-- Syncthing media folder -> /run/syncthing-files (bind)
opi5p     /mnt/storage/media     <-- Syncthing media folder -> /run/syncthing-files (bind, NFS)
greencloud /nix/persistent/media
ml-laptop  /nix/persistent/media
```

## 实施方式

- 各机启用 `nixos/optional-apps/syncthing`（模块 1:1 复刻作者，storage 走
  bind 视图 `/run/syncthing-files`，`overrideFolders=false`、
  `overrideDevices=false`、`autoAcceptFolders=true`）。
- 用 Syncthing 官方 REST API 在四台机器上完成 device 配对与 media folder 关联：
  - device 列表 = 其他三台全连，device name 对齐为 hostname。
  - media folder 指向各自 `/run/syncthing-files`，devices 含全部四台。
  - 删除旧的 `notes` folder 与脏 device 名（`colocrossing`/`ml-builder-cache`）。
- 不引入仓库内脚本；不手改 config.xml 内容结构。

## 权限关键点（排障结论）

- syncthing 以 uid 237（syncthing:syncthing）运行，需对 media 根目录有属主权限
  才能对其 chmod 对齐权限位。
- **ml-2700**：media 根本来属主就是 `syncthing:syncthing`，无此问题。
- **opi5p**：media 根落在 qnap NFS（`192.168.0.40:/nixos`），根下 Notes 属主原为
  `zhyi:zhyi`，syncthing 无法 chmod → errors=373。`chown syncthing:syncthing`
  media 根后重启 syncthing，errors 归零。（NFS 上 root 可 chown，qnap 未 squash
  root 写；rsgain 服务以 root 运行，chown 不影响其写 CloudMusic。）
- 触发错误后需 `systemctl restart syncthing` 才能清掉历史缓存错误，
  仅 REST rescan 不刷新 status 的 errors 计数。

## 验收标准

- ml-2700 / opi5p / greencloud / ml-laptop 的 `media` folder 状态为 `idle`、
  `needBytes=0`、`errors=0`。
- 四台 media folder 的 devices 均为四台 ID 全连。
- 每台仅保留 `media` 一个 folder（无残留 `notes` / 脏 device）。
- 文档与本文件同步更新。

## 完成记录（2026-08-20）

- 四台 mesh 已建成：ml-2700 / opi5p / greencloud / ml-laptop 均为
  `media` folder（指向各自 `/run/syncthing-files`）、errors=0、inSync=343、
  needBytes=0。
- device 名已对齐：greencloud / ml-2700 / opi5p / ml-laptop。
- 已清理测试残留 `.testdir`/`.testperm` 与 opi5p 上多余的 `notes` folder。
- 未引入自定义 bindfs 挂载；media 与 nixos-config 是两个独立 git 仓库。

## 回滚

1. 删除 `Notes` 中测试期间复制的 docs 文件，恢复原状。
2. 提交并 push Gitea 回滚提交。
3. 通过 Syncthing GUI/REST 撤销三台机器的配对与文件夹。
4. 从 ml-2700 配置中移除 syncthing 模块并重新 apply。
