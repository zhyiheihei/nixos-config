# preservation 学习笔记

## 1. 是什么

`preservation` 提供 **NixOS 非易失状态（persistent state）的声明式
管理**，MIT，339 star，要求至少 nixos-24.11，并且强制使用 systemd
initrd（配置里有 assertion）。它受
[impermanence](./impermanence.md) 启发，但不是替代品，目标是在
“无解释器”的 NixOS 上也能做 impermanence 式持久化。

项目文档里关联了两个背景：

- [NixOS/nixpkgs#265640](https://github.com/NixOS/nixpkgs/issues/265640)；
- nix-community/projects 的 nixpkgs-security-phase2 提案
  （boot chain security），即系统启动链上最好少依赖 bash 激活脚本。

## 2. 核心配置模型

模块只有一个根选项 `preservation.preserveAt`，以“持久化根目录”为
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
    users = {
      alice.directories = [ ".rabbit_hole" ];
      butz.files = [ { file = ".config/foo"; mode = "0600"; } ];
    };
  };
};
```

每个文件/目录项都有精细控制：

- `how`：`bindmount`（默认，两边建目录/文件再 bind）、`symlink`
  （易失侧放符号链接指向持久侧）、`_intermediate`（只建中间目录，
  内容不保留）；
- `inInitrd`：是否在 initrd 阶段就准备好（`/etc/machine-id` 这种
  必须很早就可读的例外场景）；
- `user`/`group`/`mode`：持久侧和易失侧各自的权限；
- `configureParent` + `parent.*`：控制路径父目录的 owner/mode，
  默认只为“非 root 用户的 symlink”自动开；
- `mountOptions`：bind 默认带 `X-fstrim.notrim`（目录），可
  `mkForce` 覆盖；顶层和用户级还有 `commonMountOptions` 统一追加；
- `createLinkTarget`：symlink 时是否同时在持久侧创建空文件/目录。

## 3. 实现方式

`module.nix` 只生成两类静态 systemd 配置，不写 bash 激活逻辑：

1. `systemd.tmpfiles.settings.preservation`：创建持久/易失两侧的
   文件、目录、symlink，并设置属主和模式；
2. `systemd.mounts`：把易失路径 bind 到持久路径。

普通阶段挂在 `preservation.target`（`before sysinit.target`），
initrd 阶段挂在 `initrd-preservation.target`，临时路径前缀是
`/sysroot`。文件 bind 还带 `ConditionPathExists`，持久文件不存在时
自动跳过，避免挂到空路径。

`lib.nix` 把“找出所有被保留的路径、生成中间目录、过滤 bind/symlink、
生成 rules/mount units”拆成纯函数，flake 也导出 `lib`，方便外部
复用和测试。

## 4. 与 impermanence 的差异

- 只针对 NixOS，不支持 home-manager 独立使用；
- 只产出 tmpfiles + mount unit，而 impermanence 用 activation
  scripts 和 bash 服务；
- 有全局 `preservation.enable`，impermanence 没有；
- 没有隐式的 `hideMounts`，改为显式 `commonMountOptions`
  （例如 `x-gvfs-hide` / `x-gdu.hide`）；
- “何时持久化、怎么持久化、父目录权限”都要显式配置，换来的是
  可静态推导、更适合 interpreter-less 启动链。

## 5. 测试与 CI

`tests/` 下有完整 NixOS 集成测试：

- `basic`：覆盖 bind/symlink/intermediate、SSH host key、
  machine-id、用户路径权限、跨 reboot 保留和自定义 mount options；
- `firstboot`：验证 `ConditionFirstBoot` 语义下 machine-id 用
  symlink + `systemd-machine-id-commit` 持久化；
- `verity-image`：tmpfs `/` + dm-verity 保护的 `/nix/store`
  appliance 镜像场景，验证易失根和持久化状态能协同工作。

CI 用 Lix 安装器跑 `nix flake check` 和全部 nixosTest；docs 由
`nixosOptionsDoc` 自动生成选项文档后用 mdBook 构建，推到 GitHub
Pages。

## 6. 对我们仓库的启发

- 我们仓库已经有 impermanence 和 `/nix/persistent` 布局，preservation
  可以作为“无激活脚本”变体的参考实现；
- “持久化细节全部显式化 + 纯函数生成 systemd 配置”是提升启动链
  可审计性的好思路，适合评估是否引入到我们的 client 主机；
- `/etc/machine-id`、SSH host keys、systemd random-seed 这些特殊
  文件需要 `inInitrd` / symlink / parent 配置，文档和测试都写得很
  清楚，可直接对照我们的持久化清单。

## 7. 参考

- [preservation](https://github.com/nix-community/preservation)
- [preservation 文档](https://nix-community.github.io/preservation)
- [impermanence](./impermanence.md)
