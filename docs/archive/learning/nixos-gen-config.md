# nixos-gen-config 学习笔记

## 1. 是什么

`nixos-gen-config` 是 Artturin 写的 **nixos-generate-config 的
Python 重写版**（实验性）：检测硬件并生成
`hardware-configuration.nix` / `configuration.nix`。9 star，
pyproject 标注 MIT（无 LICENSE 文件），Python 3.9+，2023-05 后
基本停更。

## 2. CLI

```sh
nixos-gen-config [--root /] [--dir /etc/nixos1] [--force]
                 [--no-filesystems] [--show-hardware-config] [--debug]
```

- `--show-hardware-config`：只把硬件配置打印到 stdout；
- `--no-filesystems`：省略文件系统/swap 部分；
- `--debug`：icecream 调试输出。

## 3. 实现

`src/nixos_gen_config/` 模块化清晰：

- `hardware.py`：`cpu_section` 读 `/proc/cpuinfo` 判 AMD/Intel 的
  updateMicrocode、`svm`/`vmx` 加 kvm 模块、按
  `scaling_available_governors` 设 cpufreq governor；
  `udev_section` / `pci` 用 pyudev 遍历设备，收集 initrd 需要的
  USB 键盘驱动、PCI 类驱动（带 driver_overrides 缩写）；
- `partitions.py`：`psutil.disk_partitions(all=True)` 过滤
  `--root` 前缀和特殊挂载点，用 pyudev 找 UUID 换成稳定的
  `/dev/disk/by-uuid/...`，套模板生成 `fileSystems`；
- `write_config.py`：写两份配置文件；`classes.py` 维护累积的
  attr/kernel module 列表。

## 4. 测试与工程

- `tests/assets/` 有 AMD/Intel cpuinfo 和 governor 样本，pytest +
  pytest-mock 覆盖硬件与分区逻辑；
- flake：poetry2nix `mkPoetryApplication`（依赖 pyudev/icecream/
  psutil，buildInputs 加 udev），checkPhase 跑
  `mypy --strict` + pytest；CI 用 `nix build`；
- devShell：pyright/poetry/mypy/black/pylint。

## 5. 对我们仓库的启发

- 我们的主机仍用官方 nixos-generate-config，不需要换；
- “pyudev + psutil 做硬件检测，UUID 稳定路径写 fileSystems”是
  比 shell 版更可测的写法；若以后要给新主机做硬件探测工具，
  可直接参考它的测试组织。

## 6. 参考

- [nixos-gen-config](https://github.com/nix-community/nixos-gen-config)
