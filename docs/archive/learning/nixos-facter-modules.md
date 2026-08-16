# nixos-facter-modules 学习笔记

## 1. 是什么

`nixos-facter-modules` 是一组配合 [NixOS Facter](https://github.com/nix-community/nixos-facter) 的
NixOS modules：读 `facter.json` 硬件报告，按“细粒度硬件特性”自动启用
或禁用对应配置，目标类似 NixOS Hardware 但基于实际检测而不是机型
profile。

仓库已弃用：模块已上游到 nixpkgs，现在应直接使用

```nix
{
  hardware.facter.reportPath = ./facter.json;
}
```

## 2. 工作原理

- 主模块 `modules/nixos/facter.nix` 定义 `facter.report` 和
  `facter.reportPath`，并 import 各特性模块：bluetooth、boot、camera、
  disk、fingerprint、firmware、graphics、keyboard、networking、
  virtualisation 等；
- 特性模块读取报告里的具体字段决定默认值，例如：
  - fingerprint：按 USB 设备的 vendor/device ID 查 `devices.json`；
  - graphics：收集 `driver_modules` 作为 initrd kernel modules，
    AMD 检测 `amdgpu`；
  - networking：按 `sub_class` 过滤物理网卡（Ethernet/WLAN/USB-Link）
    自动生成 DHCP 配置；
  - boot：按 `report.uefi.supported` 开启 grub efiSupport；
- `lib/lib.nix` 提供 `hasCpu`、`collectDrivers`、`stringSet`、
  `toZeroPaddedHex` 等辅助函数。

## 3. 工程与 CI

- flake 导出 `nixosModules.facter`、`lib`、测试 VM
  （`hosts/basic` + `report.json`）；
- checks：formatting、`lib-tests`（nix-unit）、
  `minimal-machine`（直接 `nixos` 求值构建）；
- 另有 `fprint-supported-devices` 包和更新设备表的脚本；
- `gh-pages.yml` 用 mike 部署 mkdocs；mergify 依赖
  `buildbot/nix-eval` 检查（nix-community 自己的 buildbot-nix）。

## 4. 对我们仓库的启发

- 我们每个 host 用 `hardware-configuration.nix`，由
  `nixos-generate-config` 生成并手工维护，不需要迁移；
- 它的“检测字段 → 默认开关”模式适合作为硬件自动化的参考；但模块
  已进 nixpkgs，要复用直接用 `hardware.facter`。

## 5. 参考

- [nixos-facter-modules](https://github.com/nix-community/nixos-facter-modules)
- [NixOS Facter](https://github.com/nix-community/nixos-facter)
- [nixpkgs facter 文档](https://search.nixos.org/options?query=facter)
