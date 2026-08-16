# disko 学习笔记

## 1. 是什么

`disko`（Numtide 维护，MIT，3241 star）把 **磁盘分区、格式化、
挂载** 变成 Nix 声明。NixOS 安装中唯一还靠手工的部分由此可复现，
适合无值守安装、崩溃后重装、批量部署相同服务器。

## 2. 配置模型

核心选项是 `disko.devices`，按 `disk -> content` 递归描述：

```nix
disko.devices.disk.my-disk = {
  device = "/dev/sda";
  content = {
    type = "gpt";
    partitions = {
      ESP = {
        type = "EF00";
        size = "500M";
        content = {
          type = "filesystem";
          format = "vfat";
          mountpoint = "/boot";
        };
      };
      root = {
        size = "100%";
        content = {
          type = "filesystem";
          format = "ext4";
          mountpoint = "/";
        };
      };
    };
  };
};
```

支持的类型包括：

- 分区表：GPT / MBR / mixed；
- 分区工具：LVM、LVM RAID、mdadm、LUKS、ZFS、bcachefs；
- 文件系统：ext4、btrfs、ZFS、bcachefs、tmpfs 等；
- 递归组合，例如 LUKS 里再放 LVM，再放 btrfs 子卷。

## 3. CLI 与模块

- `nix run github:nix-community/disko -- --mode destroy,format,mount <config>`：
  destroy 清空、format 建分区、mount 挂载；
- `disko-install`：把 disko + `nixos-install` 合并成一步；
- NixOS module 会在 `system.build` 暴露 `diskoScript`，并可在切换时
  调用 `mount` / `format`；
- flake 输出 `lib`（`makeDiskImages` 等）用于生成镜像；
- `lib/make-disk-image.nix` 可离线产出 raw/qcow2 磁盘镜像。

## 4. 测试与 CI

`tests/` 用真实 NixOS VM 跑多种布局，flake 的 checks 只启
x86_64 上的 NixOS tests（aarch64 有已知 boot 挂起问题），另有
`disko-install` 测试、jq 语法检查和 treefmt。GitHub Actions 直接
看 `nix flake check` 的结果。

## 5. 与我们仓库的关系

我们的新主机流程和 docs 已经围绕“tmpfs `/` + `/nix` +
`/nix/persistent`”布局，disko 是把它声明化的首选：

- 物理 client 布局（EFI + Btrfs `/nix` + persistent 子卷）可直接
  写成 disko config；
- `nixos-anywhere` 依赖 disko，所以装机链路是统一的；
- 已经存在的 disko-templates 笔记（`disko-templates.md`）保存了
  常见布局模板，包括 ZFS 变体。

## 6. 参考

- [disko](https://github.com/nix-community/disko)
- [disko 文档](https://nix-community.github.io/disko/)
- [disko-templates](disko-templates.md)
