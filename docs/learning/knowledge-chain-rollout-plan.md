# 知识链简化测试规划

状态：按用户确认执行简化路径；不引入自定义 bindfs 挂载。

用户确认：开工；先把项目 `docs/` 下的现有文件复制进 `Notes` 作为测试笔记，
走 git -> Gitea 私有仓库链路。

## 角色映射

| 角色 | 作者原版 | 我们 |
| --- | --- | --- |
| 主力客户端 | `lt-hp-omen` | `ml-2700` |
| 家庭数据服务器 | `lt-home-vm` | `opi5p` |
| 公网异地节点 | `colocrossing` | `colocrossing` |

角色映射保留。Syncthing 使用官方模块和 REST API 做三机文件夹同步，不引入自定义
bindfs 挂载。

## 目标

```text
ml-2700
  /home/zhyi/Documents/Notes    <- 普通目录，不做挂载
     内容 = 项目 docs/ 的现有笔记
  git commit -> push Gitea zhyi/notes

opi5p
  /mnt/storage/media/Notes      <- Syncthing 家庭副本

colocrossing
  /nix/persistent/media/Notes   <- Syncthing 异地副本
```

## 实施内容

- 保持 `~/Documents/Notes` 为普通目录。
- 把 `/nix/src/nixos-config/docs/` 下的文件复制进 `Notes`。
- 在 `Notes` 仓库提交并 push 到 `ssh://git@git.zhyi.xin:2222/zhyi/notes.git`。
- 启用 `nixos/optional-apps/syncthing`，`syncthing` 用户加入 `zhyi` 组并开放
  Notes 写权限；Syncthing 文件夹直接指向 `~/Documents/Notes`，不使用 bindfs。
- 用 `tools/knowledge-chain/syncthing-setup.py` 在 ml-2700 / opi5p / colocrossing
  三台机器上完成官方 REST 配对。
- 保留 GPG、SSH 权限与 `knowledge-chain-init`。

不新增自定义 bindfs 挂载、不做 `.git` 符号链接。

## 验收标准

- ml-2700：`~/Documents/Notes` 包含项目 docs 的测试笔记，git 可提交并 push Gitea。
- Gitea `zhyi/notes` 能 `git ls-remote` 看到新提交。
- ml-2700 / opi5p / colocrossing 的 `notes` 文件夹状态为 `idle`、`needBytes=0`、
  `errors=0`。
- 文档与本文件同步更新。

## 回滚

1. 删除 `Notes` 中测试期间复制的 docs 文件，恢复原状。
2. 提交并 push Gitea 回滚提交。
3. 使用 `syncthing-setup.py --action remove` 撤销三台机器的配对与文件夹。
4. 从 ml-2700 配置中移除 syncthing 模块并重新 apply。
