# hpe-ltfs 学习笔记

## 1. 是什么

`hpe-ltfs` 是 redvers 维护的 **HPE LTFS 源码镜像**：Linear Tape
File System（LTO 双分区磁带机的 FUSE 文件系统）HPE StoreOpen
3.4.2。24 star，LGPL-2.1，C 源码，2021-10 后停更。仓库本身没有
Nix 表达式，只是把 HPE/IBM 版权源码原样托管到 nix-community，方便
Nix 生态引用和打包。

## 2. 内容

- `ltfs/`：autotools 工程，`configure.ac` + `src/`：
  - `libltfs` 核心；
  - `tape_drivers`：ltotape（Linux）、ibmtape、osx iokit；
  - `iosched`：unified / fcfs 调度器；
  - `kmi`：内核挂载接口；
  - `utils`：`mkltfs`（格式化）、`ltfs`（挂载）、`ltfsck`
    （修复/回滚索引）、`unltfs`（擦除格式）；
- `BUILDING.linux` / `BUILDING.macosx`：构建说明（libicu 50.1.2、
  fuse 2.8.5+、libxml2、e2fsprogs）；
- 许可文件为 LGPL-2.1，含 HPE/IBM 版权声明。

## 3. 用途与限制

- `mkltfs -d /dev/st0` 格式化磁带，`ltfs /mnt/lto5` 挂载；
- 支持 index partition 小文件规则（`size=1M/name=*.jpg`）、
  卷防写/回滚挂载、LTO7/LTO8 追加写、SNIA 2.4 特性；
- 磁带快满时只读、卸载前保留索引空间等是磁带文件系统的硬约束。

## 4. 对我们仓库的启发

- 我们没有磁带设备，不引入；
- 这个仓库的意义是“把厂商开源但托管不稳定的源码镜像进组织，
   供 nixpkgs/zhyi-packages 固定 fetch”，和 hpe-ltfs 类似的还有
   一批源码镜像类 org 仓库；
- 若以后在 zhyi-packages 打包需要镜像源的 C 项目，可照此模式：
   镜像 + 记录上游版本/license/构建依赖，但**不要**在镜像仓库里
   夹带 Nix 表达式（保持纯净，便于同步）。

## 5. 参考

- [hpe-ltfs](https://github.com/nix-community/hpe-ltfs)
