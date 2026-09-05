# 上游对齐基线（exam）

本仓共享路径（清单见 `tools/exam-check` 的 `SHARED_PATHS`）对齐上游
xddxdd/nixos-config 的同步点。`tools/exam-check log` 据此计算上游增量，
`tools/exam-check` 据此审计漂移；同步流程见 work-norms §3。

baseline: 185a4a15f66fdfd69cba098ba52f909b6892193a

| 日期       | baseline | 说明                                                                                                     |
|------------|----------|----------------------------------------------------------------------------------------------------------|
| 2026-09-05 | 185a4a15 | 初次建档，对应上游 2026-09-03 HEAD。attic/dex/nextcloud/nfs/ghostty 公共模块已还原上游原版；既有行为漂移登记于 tools/exam-check-allowlist，逐个清偿 |
