# 上游对齐基线（exam）

本仓共享路径（清单见 `tools/exam-check` 的 `SHARED_PATHS`）对齐上游
xddxdd/nixos-config 的同步点。`tools/exam-check log` 据此计算上游增量，
`tools/exam-check` 据此审计漂移；同步流程见 work-norms §3。

baseline: b095b488dff9fa93e1bf14344f44003bf03ce7cb

| 日期       | baseline | 说明                                                                                                     |
|------------|----------|----------------------------------------------------------------------------------------------------------|
| 2026-09-05 | 185a4a15 | 初次建档，对应上游 2026-09-03 HEAD。attic/dex/nextcloud/nfs/ghostty 公共模块已还原上游原版；既有行为漂移登记于 tools/exam-check-allowlist，逐个清偿 |
| 2026-09-05 | b095b488d | 首次 SOP 实测同步：消化上游 8 提交（bambu-studio 改 nixpkgs 源、dlx 新服务模块、decluttarr 移除、waline 评审模型、auto 包更新）。packages.nix/sonarr/default.nix/ports.nix 为接管文件手动搬 patch；dlx 模块整体采纳（无主机导入，惰性）；auto 提交仅动 flake.lock/_sources，本仓自更新不跟随 |
