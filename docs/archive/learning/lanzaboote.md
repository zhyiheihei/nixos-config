# lanzaboote 学习笔记

## 1. 是什么

`lanzaboote` 是 blitz / raitobezarius / nikstur 维护的 **NixOS UEFI
Secure Boot & Measured Boot** 工具链（GPL-3.0，Rust + Nix，1787
star，2026-08 仍在活跃）。目标：只让受信任的内核/initrd 能启动，
并可用 TPM 测量把磁盘解密密钥绑定到引导策略。

## 2. 核心：UKI + lzbt

- NixOS 用 [bootspec](https://github.com/NixOS/rfcs/pull/125)
  描述引导配置（NixOS 23.05 起默认启用）；
- `lzbt`（Linux CLI）：读 bootspec → 签名相关文件 → 组装
  **Unified Kernel Image (UKI)** → 装进 ESP；能同时处理多个
  generation；
- **自定义 UEFI stub**：`systemd-stub` 要求把 kernel+initrd 打进
  UKI，占用 ESP；Lanzaboote 的 stub 允许 kernel/initrd 分开存放，
  用“签名内核 + 把 initrd 哈希嵌入已签名 UKI”维持信任链；
- `services.fwupd` 开启时，preStart 放一份签名 fwupd 到 /run。

## 3. 工程

- `rust/`：stub（UEFI）、lzbt、签名相关；
- `nix/`：NixOS module（`boot.lanzaboote` 等）与打包；
- 文档在 nix-community.github.io/lanzaboote；examples、checks、
  fwupd 集成；
- 与 goblin-signing（已学）配套：PKCS#11 签 UEFI 二进制。

## 4. 对我们仓库的启发

- 我们目前没启用 Secure Boot（主机多为 server/VM），不引入；
- 若以后给物理机开 UEFI Secure Boot，lanzaboote 是 NixOS 标准
  方案；
- “签名引导链 + UKI + TPM 绑定 LUKS”的架构值得在安全设计文档
  里记录。

## 5. 参考

- [lanzaboote](https://github.com/nix-community/lanzaboote)
