# Attic 客户端旧缓存与无效 Store Path 排障

本文记录一次 Attic 数据库和 S3 存储桶重建后，客户端持续出现
`Bad chunk hash or size` 和 NAR hash mismatch 的排障过程。

## 已确认的根因

Attic 数据库和 S3 被清空并重新创建后，同一个 store path 的 narinfo 和
NAR 内容发生了变化，但客户端仍保留旧的 narinfo 缓存：

```text
/root/.cache/nix/binary-cache-v7.sqlite
```

Nix 使用旧 `NarHash` 校验 Attic 当前返回的 NAR，因此稳定复现 hash
mismatch。此前被中断的 `nix copy` 还在 `/nix/store` 中留下了未注册、内容
不完整的目录，使现象看起来像 Attic 或 S3 已损坏。

本次已验证以下环节彼此一致：

- Attic 数据库中的对象信息
- S3 中压缩对象的大小和 hash
- 解压后的 NAR hash
- atticd 本地接口返回内容
- Caddy 公网反代返回内容
- Attic narinfo 签名与数据库私钥生成的 Nix 原生签名

因此本次问题不在 Attic、S3、Caddy 或签名，而在客户端旧 narinfo 缓存和
中断操作留下的无效 store path。

## 识别问题

先验证报错的 store path：

```bash
P=/nix/store/xxxxxxxx-name
nix-store --verify-path "$P"
nix-store --query --hash "$P"
```

如果 `--verify-path` 报 `was modified`，再确认该路径是否已在本地数据库注册：

```bash
nix-store --query --valid-derivers "$P"
nix path-info "$P"
```

不要因为单个路径失败就清空整个 `/nix/store`、Attic 数据库或 S3。

## 修复客户端旧 narinfo 缓存

以下操作只删除 root 用户的二进制缓存元数据，不删除 Nix store：

```bash
systemctl stop nix-daemon.socket nix-daemon.service

rm -f /root/.cache/nix/binary-cache-v7.sqlite \
  /root/.cache/nix/binary-cache-v7.sqlite-shm \
  /root/.cache/nix/binary-cache-v7.sqlite-wal

systemctl start nix-daemon.socket
```

普通用户执行 Nix 命令时，也可能存在对应的
`~/.cache/nix/binary-cache-v7.sqlite`，应只清理实际发起请求的用户缓存。

## 清理无效的残留路径

只处理已经由 `nix-store --verify-path` 确认损坏，并且未在 Nix 数据库中有效
注册的具体路径。不要批量删除 store。

如果 NixOS 将 `/nix/store` 以只读 bind mount 暴露，可临时执行：

```bash
mount -o remount,bind,rw /nix/store
rm -rf /nix/store/xxxxxxxx-name
mount -o remount,bind,ro /nix/store
```

随后从缓存重新导入该路径，并再次验证：

```bash
nix copy --from https://attic.zhyi.cc:4000/lantian /nix/store/xxxxxxxx-name
nix-store --verify-path /nix/store/xxxxxxxx-name
```

## 首次引导签名

本次 2700u 的旧系统尚未加载新 Attic 公钥，所以首次切换命令临时使用了：

```text
--option require-sigs false
```

它只用于让旧系统取得包含正确 Attic 公钥的新系统闭包，不应写入永久
`nix.conf`。切换后必须确认：

```bash
nix show-config | grep -E '^(substituters|trusted-public-keys|trusted-substituters) ='
```

当前 Attic 公钥应包含：

```text
lantian:Pi7qMC8lIOrR8cTh4vfcRuSL/z+Bh5BAFYlEo/mbq2U=
```

## 判断是否真的在本地编译

`nix` 进程占用 CPU、内存并大量写盘，不等于正在编译。下载大型 NAR 后的
解压和写入同样会产生这种现象。

可检查是否存在编译器和 build sandbox：

```bash
ps -eo pid,ppid,pcpu,pmem,comm,args | \
  grep -E 'gcc|g\+\+|clang|rustc|cargo|make|ninja|meson|/build/'
```

本次 Firefox、FreeCAD、KiCad、Electron 等主体包均通过缓存取得。最后出现的
`system-units.drv` 和 `nixos-system.drv` 是轻量系统配置拼装，不是大型软件
重新编译。

## 避免重复 rebuild

本次曾同时残留两组 `nixos-rebuild`，每个 `nix` 进程约占 3.5 GiB 内存，并
重复下载相同闭包。启动新任务前先检查：

```bash
pgrep -af 'nixos-rebuild|nix.*build|switch-to-configuration'
```

确认旧任务确实无用后，先终止旧的 `nixos-rebuild` 父进程，再确认其子进程也
已退出。不要同时运行两次针对同一 host 的 switch。

## 本次切换末尾的独立问题

2700u 完成系统生成后，在激活期间报告：

```text
Failed to start multi-user.target: Transaction ... is destructive
```

随后旧 SSH 端口 22 和新端口 2222 均未监听。这个问题发生在 Attic 下载完成
以后，属于 systemd/SSH 激活事务问题，不是缓存损坏。恢复本地控制台或重启
后，应检查：

```bash
systemctl is-system-running
systemctl --failed --no-pager
systemctl status sshd --no-pager -l
systemctl is-active multi-user.target graphical.target
```

2700u 的正确 SSH 入口是局域网主机名或 IP，不使用公网域名：

```bash
ssh -A -p 2222 root@ml-2700u
ssh -A -p 2222 root@192.168.2.237
```
