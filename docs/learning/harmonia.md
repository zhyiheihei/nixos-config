# harmonia 学习笔记

## 1. 是什么

`harmonia` 是 Rust 写的 Nix 二进制缓存服务器，直接把自己的 `/nix/store`
通过 HTTP 作为 binary cache 提供给其他机器。

## 2. 特点

- nar 文件 HTTP range 流式传输；
- streaming build logs；
- `.ls` 文件流式输出，供 `nix-index` 使用；
- zstd 透明压缩；
- 内置 TLS；
- 支持 `/serve/<narhash>/` 直接服务 store 内容；
- 暴露 Prometheus metrics。

## 3. NixOS 使用

```nix
services.harmonia.enable = true;
services.harmonia.signKeyPaths = [ "/var/lib/secrets/harmonia.secret" ];
```

配合 nginx 反向代理和 ACME 就是标准公共缓存。客户端使用：

```nix
nix.settings.substituters = [ "https://cache.example.com" ];
nix.settings.trusted-public-keys = [ "cache.example.com-1:..." ];
```

## 4. 与 Attic 的对比

- Attic：多租户、带权限管理，适合团队/多项目；
- Harmonia：单机简单、Rust 高性能，适合把本机 store 快速发布为缓存；
- 我们目前用 Attic（`attic.zhyi.xin/lantian`），不需要切换；
- buildbot-nix 的本地缓存示例就是 harmonia，说明两者可以互补。

## 5. 参考

- [harmonia](https://github.com/nix-community/harmonia)
