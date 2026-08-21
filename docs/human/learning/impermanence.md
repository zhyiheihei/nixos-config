# 易失根持久化：impermanence 与 preservation（学习笔记）

## 1. impermanence：是什么

`impermanence` 让 NixOS 用户 **只保留声明过的状态，其余每次重启
丢弃**（MIT，1859 star）。做法是易失根文件系统（tmpfs 或每次新建
Btrfs 子卷）+ 持久卷 + 模块在两者之间做 symlink 或 bind mount。

好处：

- 系统默认干净，用户被迫把想留的状态写进配置；
- 实验软件不会在系统里留下垃圾；
- 声明式重建一台机器时，持久化清单也随配置走。

## 2. impermanence 配置模型

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
- 顶层 attr 是持久存储挂载点，可配置多个（可备份 / 不可备份）；
- `directories` / `files` 是绝对路径，`users.<name>` 下是相对 `$HOME`；
- 字符串是简写，submodule 可指定 `user` / `group` / `mode` /
  `parentDirectory`；
- `hideMounts` 加 `x-gvfs-hide`，`allowTrash` 加 `x-gvfs-trash`。

## 3. impermanence 实现

- `nixos.nix` / `home-manager.nix`：两个入口模块；
- `submodule-options.nix`：所有路径选项；
- `lib.nix`：把配置转成 mount/symlink 列表；
- `mount-file.bash` / `create-directories.bash`：activation 阶段
  实际创建持久目录、绑定或链接；
- 每个用户/路径都用 NixOS activation scripts 准备，目录权限在首次
  创建时按声明设置，之后不改。

## 4. preservation：无解释器变体

`preservation` 提供 NixOS 非易失状态的声明式管理（MIT，339 star，
要求 nixos-24.11 + systemd initrd）。受 impermanence 启发但**不是
替代品**，目标是在"无解释器"（interpreter-less）启动链上也能做
impermanence 式持久化。

模块只有一个根选项 `preservation.preserveAt`，以"持久化根目录"为
键组织要保存的状态：

```nix
preservation = {
  enable = true;
  preserveAt."/state" = {
    directories = [ "/var/lib/someservice" "/var/log" ];
    files = [
      { file = "/etc/machine-id"; inInitrd = true; }
      { file = "/etc/ssh/ssh_host_ed25519_key"; how = "symlink"; configureParent = true; }
    ];
    users.alice.directories = [ ".rabbit_hole" ];
  };
};
```

- `how`：`bindmount`（默认）、`symlink`、`_intermediate`；
- `inInitrd`：是否 initrd 阶段就准备好（`/etc/machine-id` 例外）；
- `configureParent` + `parent.*`：父目录 owner/mode；
- 只生成 `systemd.tmpfiles` + `systemd.mounts` 静态配置，不写 bash
  激活逻辑；initrd 阶段前缀 `/sysroot`。

## 5. 两者差异

| 维度 | impermanence | preservation |
| --- | --- | --- |
| 范围 | NixOS + home-manager | 仅 NixOS |
| 实现 | activation scripts + bash | 纯 tmpfiles + mount unit |
| 全局开关 | 无 | 有 `enable` |
| 隐藏挂载 | 隐式 `hideMounts` | 显式 `commonMountOptions` |
| 适用场景 | 常规易失根 | interpreter-less 启动链 |

`preservation` 的测试覆盖 bind/symlink/intermediate、SSH host key、
machine-id、首次启动语义和 dm-verity appliance 镜像。

## 6. 对我们仓库的启发

- 物理 client 布局就是 impermanence 模式：tmpfs `/` + Btrfs `/nix` +
  `/nix/persistent`；`/nix/persistent/etc/ssh` 必须在安装前准备好
  host keys；从普通 ext4 root 在线切换会导致 systemd/SSH 卡死，
  必须按安装环境重装。
- `environment.perform` 清单应与文档、新主机规范同步；新增服务时先
  问"这个状态要不要持久化"。
- preservation 的"纯函数生成 systemd 配置"思路适合评估是否引入；
  `/etc/machine-id`、SSH host keys、random-seed 特殊文件可直接对照
  我们的持久化清单。

## 7. 参考

- [impermanence](https://github.com/nix-community/impermanence)
- [preservation](https://github.com/nix-community/preservation)
