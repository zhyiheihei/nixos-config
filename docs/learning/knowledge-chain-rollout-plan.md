# 知识链 Syncthing 三节点实施规划

状态：待确认。本文是实施蓝图，不代表已改动任何主机配置。

## 角色映射

按作者原版 `nixos-config-exam` 对照：

| 角色 | 作者原版 | 我们 |
| --- | --- | --- |
| 主力客户端 | `lt-hp-omen` | `ml-2700` |
| 家庭数据服务器 | `lt-home-vm` | `opi5p` |
| 公网异地节点 | `colocrossing` | `colocrossing` |

作者原版证据：

- `lt-hp-omen`：`~/Documents` bind 自 `/nix/persistent/media/Documents`，同时导入
  `nixos/optional-apps/syncthing`。
- `lt-home-vm`：`lantian.syncthing.storage = "/mnt/storage/media"`，家庭数据池。
- `colocrossing`：导入同一 syncthing 模块，storage 使用默认
  `/nix/persistent/media`，作为异地镜像。

## 目标拓扑

```text
ml-2700 (客户端)
  /nix/persistent/media/Notes  <- Syncthing 同步目录
  bindfs -> /home/zhyi/Documents/Notes
  .git -> /nix/persistent/notes-git（同步目录外）

opi5p (家庭服务器)
  /mnt/storage/media/Notes     <- 家庭权威副本

colocrossing (公网)
  /nix/persistent/media/Notes  <- 异地镜像
```

## 实施内容

### ml-2700

- 重新启用 `nixos/optional-apps/syncthing`，设置
  `lantian.syncthing.storage = "/nix/persistent/media"`。
- `Notes` 目录位于 `/nix/persistent/media/Notes`，通过 bindfs 展示为
  `~/Documents/Notes`，对应作者 `lt-hp-omen` 的 Documents 布局。
- git 仓库本体放 `/nix/persistent/notes-git`，Notes 内 `.git` 使用符号链接，
  Syncthing 通过 `.stignore` 忽略 `.git`。
- 保留 GPG、SSH 权限、Gitea 远端与 `knowledge-chain-init`。

说明：这是对作者布局的唯一必要偏离。git 写入 0444 权限的 loose object 时，
bindfs 的 `default_permissions` 会拒绝 `O_RDWR`，因此 git 元数据必须放在同步目录外。

### opi5p

- 保留现有 Syncthing 与 `lantian.syncthing.storage = "/mnt/storage/media"`。
- 添加 `notes` 文件夹，路径 `/mnt/storage/media/Notes`。

### colocrossing

- 保留现有 Syncthing 模块，storage 使用默认 `/nix/persistent/media`。
- 添加 `notes` 文件夹，路径 `/nix/persistent/media/Notes`。

### 设备配对

`services.syncthing.overrideFolders` 与 `overrideDevices` 均为 `false`，设备和文件夹
属于运行态配置。实施时使用官方 Syncthing REST API：

- `POST /rest/config/devices`
- `POST /rest/config/folders`
- `GET /rest/db/status?folder=notes`

脚本放入 `tools/knowledge-chain/syncthing-setup.py`，幂等，支持 `--remove` 回滚，
不手工修改 XML。

## 验收标准

- ml-2700：`~/Documents/Notes` 可正常 git 提交并 push Gitea。
- opi5p、colocrossing：`notes` 文件夹状态为 `idle`、`needBytes=0`、`errors=0`。
- 三台机器 Syncthing 服务 active，无新增 failed unit。
- 文档与本文件同步更新。

## 回滚

1. 撤销 ml-2700 的 bindfs 挂载、`.git` 符号链接与 tmpfiles。
2. 使用 `syncthing-setup.py --remove` 删除三台机器的配对与文件夹。
3. 重新 apply ml-2700 / opi5p / colocrossing。
