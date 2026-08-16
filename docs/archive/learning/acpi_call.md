# acpi_call 学习笔记

## 1. 是什么

`acpi_call` 是 Linux 内核模块（fork 自 mkottman/acpi_call，由
NixOS 社区维护），允许直接调用 ACPI 方法：把方法名和参数写进
`/proc/acpi/call`。GPL-3.0，102 star，版本 1.2.2。

## 2. 用法

```sh
echo '\_SB.PCI0.PEG1.GFX0.DOFF' | sudo tee /proc/acpi/call
sudo cat /proc/acpi/call   # 返回 0xNN / 字符串 / buffer / package
```

参数类型：

- ACPI_INTEGER：`123` 或 `0x7b`；
- ACPI_STRING：`"hello"`；
- ACPI_BUFFER：`b48656c6c6f` 或 `{ 0x48, 0x65 }`。

典型场景：双显卡笔记本关闭独显（NVIDIA Optimus）、降低电池耗电、
风扇/电源控制等。

## 3. 构建与安装

- 普通 `make` + `make install`（针对当前内核）；
- 支持 DKMS（`dkms.conf.in`，构建后自动安装，可配 Secure Boot
  签名）；
- 还保留 Slackware 打包脚本（`acpi_call.build`、`doinst.sh`）。

## 4. 配套工具

- `examples/turn_off_gpu.sh`：遍历常见独显 ACPI 方法找可用的那个；
- `support/query_dsdt.pl`：扫描 DSDT 反编译文件，搜索 MXMX/_DSM
  等 token，帮助找方法名。

## 5. 对我们仓库的启发

- 我们主机以服务器为主，暂无内核模块/ACPI hack 需求；
- 如果以后有笔记本需要关独显或控制 ACPI 行为，可以用它，也可对照
  nixpkgs 里 `acpi_call` 的打包方式。

## 6. 参考

- [acpi_call](https://github.com/nix-community/acpi_call)
- [原版 mkottman/acpi_call](https://github.com/mkottman/acpi_call)
