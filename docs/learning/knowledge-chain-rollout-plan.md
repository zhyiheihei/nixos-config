# 知识链简化测试规划

状态：按用户确认调整为简化路径；不做 bindfs/Syncthing 等挂载操作。

用户确认：开工；先把项目 `docs/` 下的现有文件复制进 `Notes` 作为测试笔记，
走 git -> Gitea 私有仓库链路。

## 角色映射

| 角色 | 作者原版 | 我们 |
| --- | --- | --- |
| 主力客户端 | `lt-hp-omen` | `ml-2700` |
| 家庭数据服务器 | `lt-home-vm` | `opi5p` |
| 公网异地节点 | `colocrossing` | `colocrossing` |

角色映射保留，但本轮只做最简单的单机测试，不做三机 Syncthing。

## 目标

```text
ml-2700
  /home/zhyi/Documents/Notes    <- 普通目录，不做挂载
     内容 = 项目 docs/ 的现有笔记
  git commit -> push Gitea zhyi/notes
```

## 实施内容

- 保持 `~/Documents/Notes` 为普通目录。
- 把 `/nix/src/nixos-config/docs/` 下的文件复制进 `Notes`。
- 在 `Notes` 仓库提交并 push 到 `ssh://git@git.zhyi.xin:2222/zhyi/notes.git`。
- 保留 GPG、SSH 权限与 `knowledge-chain-init`。

不做 bindfs、不做 `.git` 符号链接、不做 Syncthing 配对；后续需要多机同步时再
单独规划。

## 验收标准

- ml-2700：`~/Documents/Notes` 包含项目 docs 的测试笔记，git 可提交并 push Gitea。
- Gitea `zhyi/notes` 能 `git ls-remote` 看到新提交。
- 文档与本文件同步更新。

## 回滚

1. 删除 `Notes` 中测试期间复制的 docs 文件，恢复原状。
2. 提交并 push Gitea 回滚提交。
3. 当前简化路径不涉及挂载或配对，无需其他撤销步骤。
