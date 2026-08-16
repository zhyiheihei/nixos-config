# nix-bundle 学习笔记

## 1. 是什么

`nix-bundle` 把 Nix derivation 打包成单文件可执行程序，目标机器不需要安装
Nix，也不需要 root。

```sh
./nix-bundle.sh hello /bin/hello
./hello
```

## 2. 原理

它把四样东西组合在一起：

- `Arx`：单文件自解压归档；
- `nix-user-chroot`：用 Linux namespace 绑定挂载 `./nix` 到 `/nix`；
- `Nix`：构建自包含 runtime closure；
- `nixpkgs`：提供要打包的软件。

## 3. 优缺点

优点：

- 单文件、无运行时、无需安装、发行版无关。

缺点：

- 启动慢；
- 文件大（Firefox 约 150MB）；
- 仅 Linux；
- 需要 `CAP_SYS_USER_NS`；
- 架构必须一致。

## 4. AppImage 实验模式

`nix2appimage.sh` 可以把带 `.desktop` 的 GUI 应用打成 AppImage，利用
SquashFS 按需解压，但需要 FUSE。

## 5. 对我们仓库的启发

我们目前用 Attic 分发二进制闭包，比 nix-bundle 更适合服务器场景。
`nix-bundle` 的价值在于理解“单文件分发”的边界：它依赖 user namespace，
容器/CI 环境经常受限。

## 6. 参考

- [nix-bundle](https://github.com/nix-community/nix-bundle)
