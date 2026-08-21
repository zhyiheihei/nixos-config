# 非 NixOS 设备加入知识链指南

本文档面向 macOS / Linux / Windows 这类非 NixOS 设备，给出加入私有知识链的完整步骤。
当前知识链由三部分组成：

- `~/Documents/Notes` 是 Markdown 笔记目录，同时也是独立 git 仓库
- Gitea 提供私有 Git 权威：`ssh://git@git.zhyi.xin:2222/zhyi/notes.git`
- Syncthing 在四台 NixOS 主机之间同步**整个 media 根目录**（含 Notes 与 Secrets，
  完全对齐作者），新设备加入后成为第五个节点

## 1. 当前节点与设备 ID

| 设备 | 角色 | Syncthing Device ID |
| --- | --- | --- |
| ml-2700 | NixOS 客户端 | `OFHULYP-EHZTYED-ZJKMBJ6-YNC3SSO-GHQD33A-IF4B6QI-IGLCDTF-VZFHJAH` |
| opi5p | 服务器 | `6OVUWPX-LFALVDJ-BMNP24B-LAQQSTJ-BJWPIN4-3TA6GFC-NGAD22X-BRK5HQZ` |
| greencloud | 服务器 | `N5O6F67-DQRWGKH-LMAOLVW-VJN53EP-MGLEXJ2-AMXHLWE-KHO4XW6-4NR64QP` |
| ml-laptop | 物理笔记本 | `7LYGWIN-NBYO45E-RXJ4M53-BEDOXRC-3UK5NSF-TFCV3ZL-ZBFKEYS-NXMFSAS` |
| Mac（本机） | 待加入 | 安装 Syncthing 后在 GUI 中查看 |

四台 NixOS 主机已建好 media 根 mesh，均为 `state=idle`、`errors=0`。media 根语义
（对齐作者）：同步整个 media storage 根（Notes / Secrets / CloudMusic 等）。

现有节点的 Syncthing Web GUI：

- `https://syncthing.ml-2700.zhyi.xin`
- `https://syncthing.opi5p.zhyi.xin`
- `https://syncthing.greencloud.zhyi.xin`
- `https://syncthing.ml-laptop.zhyi.xin`

## 2. 安装 Syncthing（macOS）

推荐使用图形界面版：

```sh
brew install --cask syncthing
open /Applications/Syncthing.app
```

首次启动后浏览器打开 `http://127.0.0.1:8384`，这是本机 Syncthing 控制台。
如果 brew 提示找不到 cask，改用 `brew install --cask syncthing-app`。

不想用图形应用时，也可以用命令行版并交给 brew services 托管：

```sh
brew install syncthing
brew services start syncthing
```

两种方式都会在本机 `127.0.0.1:8384` 提供控制台。macOS 首次访问 `~/Documents`
时会弹出文件访问授权，请允许；若仍无法读写，在“系统设置 → 隐私与安全性 →
完全磁盘访问权限”里给 Syncthing 授权。

## 3. 交换设备 ID

1. 在 Mac 控制台右上角菜单打开“显示 ID”，复制本机 Device ID。
2. 登录任一现有节点控制台，例如 `https://syncthing.ml-2700.zhyi.xin`。
3. 在“操作 → 添加远程设备”里粘贴 Mac 的 Device ID，名称填 `mac`。
4. 编辑 `media` 文件夹，在“共享”页勾选 `mac`。ml-2700 已开启自动接受文件夹；
   为了让现有节点都与 Mac 直接互通，建议在每台节点都把 `media` 共享给
   `mac`，保证完整 mesh。
5. 回到 Mac 控制台，添加三个现有节点，粘贴上表 Device ID。
6. 如果 Mac 收到 `media` 文件夹共享请求，选择接受，路径填
   `~/Documents/Notes`（Mac 只关心 Notes 子树），文件夹类型选择“发送和接收”。

验证：控制台“设备”页远程设备显示已连接；`media` 文件夹状态变为
`Up to Date` / `idle`。

## 4. 让 Syncthing 拉取 Notes

推荐目录与本仓库其他节点保持一致：

```text
~/Documents/Notes
```

首次同步时请保持该目录为空，由 Syncthing 创建并下载，不要先手工 `git clone`
到同一路径，避免目录非空导致冲突。`.git` 会随 Syncthing 一起同步，下载完成后
Notes 目录本身就是完整 git 仓库。

等待同步完成后校验：

```sh
cd ~/Documents/Notes
git status
git log --oneline -3
```

应看到干净工作区与 `21eea1b` 等现有提交。

## 5. 配置 Gitea SSH 与 Git

如果本机还没有 SSH 密钥，先生成一个：

```sh
ssh-keygen -t ed25519 -C "mac" -f ~/.ssh/id_ed25519
pbcopy < ~/.ssh/id_ed25519.pub
```

打开 Gitea `https://git.zhyi.xin/user/settings/keys`，添加 SSH 密钥，标题填
`mac`，粘贴公钥内容。

推荐在 `~/.ssh/config` 写入：

```text
Host git.zhyi.xin
  User git
  Port 2222
  IdentityFile ~/.ssh/id_ed25519
```

测试登录：

```sh
ssh -T git@git.zhyi.xin
```

出现 Gitea 欢迎信息即成功。Syncthing 同步下来的仓库已带 remote：

```sh
git -C ~/Documents/Notes remote -v
```

若 remote 缺失，手动添加：

```sh
git -C ~/Documents/Notes remote add origin ssh://git@git.zhyi.xin:2222/zhyi/notes.git
```

首次提交建议确认本机 git 身份：

```sh
git config --global user.name "zhyi"
git config --global user.email "molishanguang@outlook.com"
```

## 6. 日常使用与一致性

- Gitea 是 git 权威，Syncthing 负责文件分发。两者都会同步 `.git`，所以尽量
  单设备执行 commit / pull / push，避免两台设备同时写 `.git` 造成冲突。
- 出现 `.git` 冲突时，以 Gitea remote 为准：

```sh
git fetch origin
git reset --hard origin/master
```

  该命令会丢弃本地未提交改动，执行前先确认。
- Notes 仓库与 nixos-config 仓库保持独立，不要在 Notes 目录里放 nixos-config
  的目录、符号链接或 `.git` 指向。
- 当前四节点同步整个 media 根（含 Secrets），因此 Secrets 内容会被明文分发到
  全部节点；新增设备加入时务必确保其可信，不要在笔记/媒体里放未加密的长期凭据。
- macOS 默认会由 Time Machine 备份 `~/Documents`，覆盖 Notes 目录。

## 7. Linux / Windows 差异

Linux：

```sh
sudo apt install syncthing
systemctl --user enable --now syncthing
```

控制台同样是 `http://127.0.0.1:8384`，其余设备交换、文件夹共享、Git / SSH 步骤
与 macOS 一致。

Windows：

- 使用官方 Windows 安装包或 SyncTrayzor，控制台仍为 `http://127.0.0.1:8384`
- 文件夹路径可填 `%USERPROFILE%\Documents\Notes`
- 防火墙需放行 Syncthing 的 `22000/TCP` 监听端口

## 8. 故障排查

- 设备不连接：检查本机 `22000/TCP` 是否被防火墙拦截；Syncthing 会自动使用
  中继，设备页会显示实际连接方式。
- `needBytes` 长期不降：检查磁盘空间、文件夹权限和控制台日志。
- macOS 无法写入 Notes：检查“完全磁盘访问权限”与 Documents 访问授权。
- `ssh -T` 失败：确认公钥已加到 Gitea、`~/.ssh/config` 端口为 2222、私钥权限
  为 `600`。
- git 提示无法推送：先 `git fetch origin` 看是否落后，落后时先 pull 再 push。

## 9. 相关文档

- [作者知识链调研](../learning/author-knowledge-chain.md)
- [知识链完整链路与上游对齐审计](../learning/knowledge-chain-upstream-alignment.md)
