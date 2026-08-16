# ld-getby 学习笔记

## 1. 是什么

`ld-getby` 是 aszlig 的 `LD_PRELOAD` 小库：拦截
`getprotobyname()`，让协议列表从编译期指定的路径读取（Nix 构建
沙箱里没有 `/etc/protocols`）。MIT，1 star，2018-11 已归档。

## 2. 问题

Nix 构建沙箱没有 `/etc/protocols`，调用 `getprotobyname("tcp")`
会失败，Haskell 程序尤其常见：

```text
ConnectionFailure Network.BSD.getProtocolByName:
does not exist (no such protocol name: tcp)
```

ld-getby 在沙箱里用 `LD_PRELOAD` 拦截这个调用，从
`iana-etc/etc/protocols` 读数据，避免 `__noChroot = true`。

## 3. 实现

- `default.nix`：把 glibc 的 `nss/nss_files/files-XXX.c` 里
  `DATAFILE` 改成 iana-etc 路径编译出 `files-proto.o`，再和
  `preload.c` 链接成 `ld-getby.so`；
- `preload.c`：覆写 `getprotobyname`，内部调
  `_nss_files_getprotobyname_r`，带互斥锁和动态扩容 buffer；
- `hook` 输出提供 setup-hook，自动 `export LD_PRELOAD=...`；
- 测试：Python doctest 验证 tcp/udp/icmp 解析和未知协议报错。

## 4. 对我们仓库的启发

- 我们不需要，且已被 nixpkgs `libredirect` 取代（更通用、支持
  Darwin）；
- 它展示了“沙箱里缺 `/etc` 文件时用 preload 重定向”的临时方案
  思路，以及为什么后来要通用化。

## 5. 参考

- [ld-getby](https://github.com/nix-community/ld-getby)
