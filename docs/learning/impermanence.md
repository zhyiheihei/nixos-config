# impermanence 学习笔记

## 1. 是什么

`impermanence` 让 NixOS 用户 **只保留声明过的状态，其余每次重启
丢弃**（MIT，1859 star）。做法是易失根文件系统（tmpfs 或每次新建
Btrfs 子卷）+ 持久卷 + 模块在两者之间做 symlink 或 bind mount。

好处：

- 系统默认干净，用户被迫把想留的状态写进配置；
- 实验软件不会在系统里留下垃圾；
- 声明式重建一台机器时，持久化清单也随配置走。

## 2. 配置模型

NixOS module 提供 `environment.persistence."<path>"`：

```nix
environment.persistence."/persistent" = {
  enable = true;
  hideMounts = true;
  allowTrash = true;
  directories = [
    "/var/lib/nixos"
    "/var/log"
    { directory = "/var/lib/colord"; user = "colord"; group = "colord"; mode = "u=rwx,g=rx,o="; }
  ];
  files = [
    "/etc/machine-id"
    { file = "/var/keys/secret_file"; parentDirectory = { mode = "u=rwx,g=,o="; }; }
  ];
  users.bird = {
    directories = [ "Downloads" ".ssh" ".local/share/direnv" ];
    files = [ ".screenrc" ];
  };
};
```

要点：

- 顶层 attr 是持久存储挂载点，可以配置多个（比如一个可备份、一个
  不可备份）；
- `directories` / `files` 是绝对路径，`users.<name>` 下是相对
  `$HOME` 的路径；
- 字符串是简写，submodule 可指定 `user` / `group` / `mode` /
  `parentDirectory`；
- `hideMounts` 加 `x-gvfs-hide`，`allowTrash` 加 `x-gvfs-trash`。

## 3. 实现

- `nixos.nix` / `home-manager.nix`：两个入口模块；
- `submodule-options.nix`：所有路径选项；
- `lib.nix`：把配置转成 mount/symlink 列表；
- `mount-file.bash` / `create-directories.bash`：activation 阶段
  实际创建持久目录、绑定或链接；
- 每个用户/路径都用 NixOS activation scripts 准备，目录权限在首次
  创建时按声明设置，之后不改。

## 4. 与 preservation 的关系

preservation 是后起的“无解释器”替代实现，两者的差异已在
[preservation.md](./preservation.md) 详述：impermanence 用
activation + bash，preservation 只生成 tmpfiles/mount unit。
impermanence 支持 home-manager 独立使用，preservation 只面向
NixOS。

## 5. 对我们仓库的启发

我们仓库的物理 client 布局就是 impermanence 模式：

- tmpfs `/` + Btrfs `/nix` + `/nix/persistent`；
- `/nix/persistent/etc/ssh` 必须在安装前准备好 host keys；
- 从普通 ext4 root 在线切换会导致 systemd/SSH 卡在旧根和新持久化
  之间，必须按安装环境重装。

`environment.persistence` 清单应和我们的文档、新主机规范保持同步，
新增服务时先问“这个状态要不要持久化”。

## 6. 参考

- [impermanence](https://github.com/nix-community/impermanence)
- [preservation](./preservation.md)
- [disko-templates 的 zfs-impermanence](./disko-templates.md)
