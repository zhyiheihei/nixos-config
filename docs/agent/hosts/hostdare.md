# hostdare（流量限额 VPS）

`hosts/hostdare/*.nix` 不写注释，理由记录在本文件。

- hostdare 的流量额度小，关闭每日自动备份；需要时手动触发：
  `systemctl start backup-nix-persistent.service`。
- `hardware-configuration.nix` 由 `nixos-generate-config` 生成，不要手改结构。
