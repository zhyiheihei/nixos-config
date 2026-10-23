# google（GCP 小机型）

`hosts/google/*.nix` 不写注释，理由记录在本文件。

- 保留足够的压缩 swap 余量给构建用，并让 socket 激活的 Nix daemon 在内存压力之后能
  恢复。
- `hardware-configuration.nix` 由 `nixos-generate-config` 生成，不要手改结构。
