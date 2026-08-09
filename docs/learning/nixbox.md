# nixbox 学习笔记

## 1. 是什么

`nixbox` 是 **NixOS 的 Vagrant boxes 生成器**（HCL/Packer，
MIT，342 star，状态 stable）。它用官方 minimal ISO 自动安装并打包
出 VirtualBox、QEMU/libvirt、VMware、Hyper-V 四种平台的 `.box`
镜像，同时支持 BIOS 和 UEFI 两种启动方式，发布到 HashiCorp
Vagrant registry 的 `nixbox/nixos`。

它和已学的 [vagrant-nixos-plugin](./vagrant-nixos-plugin.md) 是一对：
nixbox 负责“开箱即用的 NixOS box”，插件负责用 Nix 表达式给运行中的
VM 继续 provision。

## 2. 构建入口

`nixos.pkr.hcl` 是 Packer 模板，几个关键设计：

- 从 `https://channels.nixos.org/nixos-<version>/latest-nixos-minimal-<arch>-linux.iso`
  动态取 ISO，校验和由 Makefile 实时从同名 `.sha256` 拉取，不写死；
- `source` 按 builder 区分：`virtualbox-iso`、`qemu`、`vmware-iso`、
  `hyperv-iso`，qemu 和 VirtualBox 各有 `-efi` 变体；
- 所有 source 共用同一个 `install.sh` 和 post-processor；
- HTTP directory 指向 `scripts/`，安装过程中 guest 通过
  `{{ .HTTPIP }}` 拉取配置片段；
- `vagrant-registry` post-processor 用 HCP client id/secret 上传到
  `nixbox/nixos`，UEFI 版本自动发布为 `<version>-efi` tag；
- qemu UEFI 用仓库里附带的 `OVMF_CODE_4M.ms.fd`（微软签名固件）。

## 3. 安装流程

`scripts/install.sh` 是典型的 Packer + NixOS 无交互安装：

1. 检测 `/sys/firmware/efi/efivars` 判断 Legacy/UEFI；
2. Legacy 用 fdisk 建一个引导分区，UEFI 用 parted 建
   `ext4 root + FAT32 ESP`；
3. `nixos-generate-config` 生成硬件配置；
4. 通过 HTTP 把 `vagrant.nix`、`bootloader.nix`、
   `vagrant-hostname.nix`、`vagrant-network.nix`、
   `builders/<type>.nix` 和主 `configuration.nix` 写进
   `/mnt/etc/nixos/`；
5. `nixos-install`，再用 `nixos-enter` 跑 `postinstall.sh`：
   清理旧 generation、`nix-collect-garbage -d`，并把磁盘零填充
   以便压缩（qemu 跳过）。

`configuration.nix` 里预置了 Vagrant 惯例：

- 创建 `vagrant` 用户和组，密码 `vagrant`，wheel 免密 sudo；
- 放的是 Vagrant 官方 insecure public key；
- 开启 OpenSSH，并兼容老 `ssh-rsa` key type；
- 默认不装 VirtualBox Guest Additions，而是各 builder 片段按平台
  启用 `virtualisation.<platform>.guest`（vboxsf / vmware / hyperv）；
- `custom-configuration.nix` 留给组织自定义。

## 4. 发布 CI

`.github/workflows/release.yml` 在 `nixos-*` 分支上触发，用
`GITHUB_REF#refs/heads/nixos-` 作为版本号，矩阵只跑 VirtualBox 和
QEMU 的 x86_64：

- VirtualBox 从 Oracle 源装 VirtualBox 7.1；
- QEMU 装 `qemu-system-x86` + libvirt；
- 两个 job 都 `continue-on-error: true`，因为 VM 镜像构建容易因
  超时等环境问题失败；
- 主仓库用 secrets 里的 HCP 凭据推 `nixbox/nixos`，fork 则推到
  `vars.HCP_REPO`。

`Makefile` 提供 `build`、`build-all`（x86_64 + i686）、`vagrant-add`、
`vagrant-up`、`packer-build` 等目标；`shell.nix` 给出带 packer、
vagrant、ruby 的开发环境。

## 5. 对我们仓库的启发

- 我们不用 Vagrant，但“官方 minimal ISO + 首启注入配置 + 平台片段”
  的镜像生成方式，和 [nixos-generators](./nixos-generators.md) 一样
  值得记住：不同 hypervisor 只差一个很小的 builder 片段；
- 把版本号直接编码进分支名（`nixos-23.11`）来自动定 release 版本，
  是个简单但有效的发布约定；
- 构建类 CI 用 `continue-on-error` 避免环境超时阻塞全部发布，适合
  ​镜像这种“失败重跑即可”的场景。

## 6. 参考

- [nixbox](https://github.com/nix-community/nixbox)
- [vagrant-nixos-plugin](https://github.com/nix-community/vagrant-nixos-plugin)
