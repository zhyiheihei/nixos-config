# nixos-anywhere-examples 学习笔记

## 1. 是什么

`nixos-anywhere-examples` 是 [nixos-anywhere](./nixos-anywhere.md)
的示例 flake，包含在不同云厂商/硬件上测试过的 NixOS 配置。98 star。

## 2. 配置

- `hetzner-cloud`（x86_64/aarch64）：disko 分区 + 公共
  `configuration.nix`；
- `digitalocean`：`digitalocean.nix` 导入
  `virtualisation/digital-ocean-config.nix`，关掉 DHCP 改用
  cloud-init 提供网络；注释里说明 1GB droplet 内存不够跑 kexec；
- `generic`：占位 hardware-configuration，用
  `nixos-anywhere --generate-hardware-config nixos-generate-config`
  生成；
- `generic-nixos-facter`：配合 nixos-facter-modules 生成
  `facter.json`。

## 3. 磁盘布局示例

`disk-config.nix`：GPT + 1M EF02 BIOS boot 分区 + 500M ESP（vfat
`/boot`）+ LVM `pool` 的 ext4 `/`，GRUB efiSupport +
efiInstallAsRemovable。

## 4. 对我们仓库的启发

- 我们日常用 colmena 管已有主机；如果以后要开新云主机
  （Hetzner/DigitalOcean），这套示例可以直接当起点；
- “--generate-hardware-config”生成 hardware/facter 报告再构建的
  流程，比手写硬件配置更稳。

## 5. 参考

- [nixos-anywhere-examples](https://github.com/nix-community/nixos-anywhere-examples)
- [nixos-anywhere 学习笔记](./nixos-anywhere.md)
