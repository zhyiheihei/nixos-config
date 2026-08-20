# macmini darwin 闭包导入加速（2026-08-20）

## 背景

macmini 首次 `darwin-rebuild switch` 卡在慢速下载（走代理约 1.2MB/s），
下载 814+ 路径，耗时超 3.5h 仍未完成。`opi5p` 的 ncps 上游是 SJTU 镜像，
无 aarch64-darwin 二进制，对 macmini 无效；attic 自有缓存也无对应路径。
决定改用 ml-builder 预拉 darwin 闭包，导入 macmini 本地 store，让 rebuild
剩余部分命中本地 store 加速。

## 数据流

1. 在 ml-builder 用 darwin 平台预拉 727 个 aarch64-darwin 路径（约 5.1GB），
   导出为单个 NAR 文件 `darwin-all.bin`。
2. scp 到 macmini 本机 `/tmp/darwin-all.bin`（5157170504 字节，已验证 sha256
   与源一致）。
3. macmini 本地 `nix-store --import` 导入全部路径。
4. 重新 `darwin-rebuild switch`，绝大多数依赖命中本地 store，跳过慢下载，
   直接本地构建 + activation。

## 关键根因：不是 ssh/管道问题，是 store 全局锁竞争

移交 agent 误判为「ssh stdin 管道 / 后台分离 / 超时」，试了 nohup 管道、
ssh stdin 管道、setsid、`sudo ... &` 后台分离——全不行。**真正根因是 nix store
的全局写锁 `big-lock` 竞争**：

- 采样调用栈（macOS `sample <pid>`）显示导入进程卡在
  `PathLocks::lockPaths → lockFile → flock`，CPU 0%、store 数不变。
- `lsof /nix/var/nix/db/big-lock` 显示锁被**当前还在跑的 `darwin-rebuild`
  的 nix-daemon 持有**（那时 rebuild 仍活着在慢速下载，占着锁不放）。
- 结论：**「边 rebuild 边 import」在 nix 里天然互斥**，导入必须写 store、必须
  拿同一把锁，只能排队等。任何 ssh/管道技巧都绕不过。

## 正确流程

### 诊断方法（可复用）

```bash
# 看导入进程是否真在推进：STAT 应为 R（运行），CPU 时间应增长
ps -o pid,etime,time,state,command -p <import_pid>

# 采样调用栈，定位卡点（flock = 等 store 锁）
sudo sample <import_pid> 2

# 看谁持有 store 全局锁
sudo lsof /nix/var/nix/db/big-lock
```

### 操作步骤

1. **先确认无 darwin-rebuild 在跑**（`ps aux | grep darwin-rebuild`）。若有，
   需先终止释放 `big-lock`（当前仅处于 nix build 阶段、未到 apply 时可安全终止）。
2. 验证 NAR 文件头合法：`od -A d -t x1 -N 16`，偏移 8-11 应为 `nix-archive-1`；
   并与源文件比对 `shasum -a 256`。
3. macmini 本地导入，**用本地文件重定向**（不走 ssh stdin 管道，最稳）：

   ```bash
   # 在 macmini 本机（或 ssh 过去执行），文件已在本机时直接 < 重定向
   nohup sudo -n /nix/var/nix/profiles/default/bin/nix-store --import < /tmp/darwin-all.bin \
     > /tmp/darwin-import.log 2>&1 &
   ```

   `nohup` 脱离 ssh 会话，进程独立存活。锁空闲时导入进程 STAT 为 R、CPU 高、
   store 数持续增长（7296→7361），日志逐路径打印。
4. 重启 rebuild（必须 `sudo`，新版 darwin-rebuild 要求 root activation）：

   ```bash
   cd ~/nixos-config
   nohup sudo -n -E /nix/store/<hash>-darwin-rebuild/bin/darwin-rebuild switch \
     --flake /Users/molishanguang/nixos-config#macmini --impure > /tmp/darwin-rebuild.log 2>&1 &
   ```

5. 若 activation 报 `/etc/bashrc`、`/etc/zshrc` 未识别内容，改名加
   `.before-nix-darwin` 后重跑（详见 hardware/macmini.md）。

## 结果

- 727 个路径全部导入成功，store 7296→7361。
- rebuild 跳过慢下载，直接本地构建（少数 Rust 包如 vscode 的 `cargo test`
  在本地编译）→ activation 完整走完。
- `/run/current-system` → `nix/store/j52frn91mvid0p3fxwam392l3bj8rmni-darwin-system-26.11.4cff07d`
- `darwin-version` = `26.11.4cff07d`，rebuild 日志无 error。

## 教训

- **导入卡死先查锁，别查 ssh/超时**。`nix-store --import` 与
  `darwin-rebuild` 对 store 写锁互斥，二者不能并发。
- macOS 无 `setsid`、无 `timeout`，用 `nohup ... &` 脱离 ssh 会话。
- macmini SSH 走 22 端口（非 2222），且不要 `-A` 转发 agent。
