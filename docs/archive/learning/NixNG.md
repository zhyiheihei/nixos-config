# NixNG 学习笔记

## 1. 是什么

`NixNG` 是一个基于 Nix 的 GNU/Linux 发行版，可以看作 NixOS 的“轻量兄弟”：
去掉 systemd，默认 minimal，面向容器。

## 2. 设计特点

- 无 systemd，可选择 runit / OpenRC / 未来 systemd；
- 默认 minimal 包集；
- 模块配置完全结构化，不用字符串 `extraConfig`；
- 适合容器（LXC/OCI）；
- 当前还不能裸机启动，只能作为容器“启动”。

## 3. 构建容器

```sh
nix build .#examples.<name>.config.system.build.ociImage.build
```

或直接跑：

```sh
nix run .#examples.<name>.config.system.build.runDocker
```

## 4. 与 NixOS 的关系

作者鼓励把 NixNG 的代码上游化到 NixOS。定位类似 Alpine 对 Debian：
裸机少见，容器场景合适。

## 5. 对我们仓库的启发

我们目前用 NixOS + 容器/VM 部署服务。NixNG 的模块结构实验（无 systemd、
minimal 容器）可以作为参考，但不改变现有架构。

## 6. 参考

- [NixNG](https://github.com/nix-community/NixNG)
