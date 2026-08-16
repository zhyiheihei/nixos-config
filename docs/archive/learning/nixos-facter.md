# nixos-facter 学习笔记

## 1. 是什么

`nixos-facter`（Clan + Numtide 维护，GPL-3.0，687 star）是
`nixos-generate-config` / `nixos-hardware` 的替代方案：它在目标机
上生成一份 **机器可读的硬件/平台 JSON 报告**，之后由 NixOS modules
根据报告做决策，而不是把硬件结论写死在生成器里。

```bash
sudo nix run nixpkgs#nixos-facter -- -o facter.json
```

## 2. 实现

Go 写的单二进制，核心是 `facter.Scanner`：

- 默认探测 memory、pci、net、serial、cpu、bios、monitor、scsi、
  usb、sys、udev、block、wlan 等；
- 通过 numtide/hwinfo 输入封装的 `hwinfo` 采集底层信息，也直接读
  udev / sysfs；
- `--hardware <features>` 可自定义探测范围；
- `--swap` / `--ephemeral` 捕获 swap、文件系统等易变信息；
- 要求 root；要求 udev >= 252；
- 输出缩进 JSON（stdout 或 `-o` 文件）。

## 3. 消费方式

消费报告的 NixOS modules 已经进 nixpkgs（`facter` options），
`nixos-facter-modules` 独立仓库已归档。这样：

- 同一份报告可以喂给不同模块；
- 硬件决策（网卡、显卡、USB、显示器）在模块层做，不用生成器
  内嵌 if/else；
- 可以 diff 两份报告排查硬件差异。

## 4. 工程组织

- flake 用 Numtide blueprint 生成 `nix/` 包结构；
- 输入 pin 了 hwinfo、disko、treefmt-nix、flake-utils；
- 支持 aarch64 / riscv64 / x86_64（macOS 仅开发用交叉编译）；
- `.github/settings.yml` / dependabot / mergify 自动化组织仓库
  维护。

## 5. 对我们仓库的启发

我们的新主机规范目前用 `nixos-generate-config` 生成
`hardware-configuration.nix`：

- facter 的“报告 JSON + 模块决策”更适合多架构、多硬件差异大的
  环境（例如我们的 ARM 开发板）；
- 如果以后要做硬件自助接入，可以先生成 facter.json 存档，再人工
  转成 host 配置；
- 它和 disko / nixos-anywhere 组合，就是“探测 -> 分区 -> 装机”
  的完整自动化链路。

## 6. 参考

- [nixos-facter](https://github.com/nix-community/nixos-facter)
- [nixos-facter 文档](https://nix-community.github.io/nixos-facter/)
- [nixos-facter-modules（已归档）](nixos-facter-modules.md)
