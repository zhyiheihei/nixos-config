# nix-user-chroot 学习笔记

## 1. 是什么

`nix-user-chroot` 让你在没有 root 的机器上安装和运行 Nix。它是
`lethalman/nix-user-chroot` 的 Rust 重写，并支持 Nix sandbox。

## 2. 原理

- 依赖非特权 user namespace（Linux 3.8+）；
- 创建用户 chroot，`/` 归当前用户所有；
- 把真实根目录 bind mount 进 chroot；
- Nix store 放在用户目录，例如 `~/.nix`；
- Nix 配置位于 `/nix/etc/nix`，而不是 `/etc/nix`。

## 3. 检查内核支持

```sh
unshare --user --pid echo YES
```

输出 `YES` 即可。Ubuntu 23.10+ 可能被 AppArmor 限制。

## 4. 安装

```sh
mkdir -m 0755 ~/.nix
nix-user-chroot ~/.nix bash -c "curl -L https://nixos.org/nix/install | bash"
```

之后进入环境：

```sh
nix-user-chroot ~/.nix bash -l
```

## 5. 配置

`~/.nix/etc/nix-user-chroot/path-config.toml` 可配置：

- `excludes`：不镜像进 chroot 的路径；
- `profile`：把用户 profile 挂进 chroot；
- `absolute`：把宿主任意路径挂到 chroot 目标。

## 6. 与我们仓库的关系

`nix-bundle` 内部就使用 `nix-user-chroot` 做单文件分发；我们在正常
NixOS 机器上不需要它，但它解释了“无 root 环境里 Nix 如何自举”。

## 7. 参考

- [nix-user-chroot](https://github.com/nix-community/nix-user-chroot)
