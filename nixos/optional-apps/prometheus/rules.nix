# MoviePilot 停摆类告警：rock5c moviepilot-watchdog 的 textfile 指标
# （订阅搜索卡死 / 刷流新增、删种停摆），经 Alertmanager 走 Telegram。
# 阈值依据见 docs/agent/inspection-playbook.md 的 moviepilot 条目。
{
  pkgs,
  lib,
  ...
}:
let
  rules = lib.trim ''
    groups:
      - name: moviepilot
        rules:
          - alert: MoviePilotSubscribeSearchStuck
            expr: moviepilot_subscribe_search_stuck_tasks > 0
            for: 15m
            labels:
              severity: warning
            annotations:
              summary: "订阅搜索队列有 {{ $value }} 个任务重试超限，疑似站点搜索游标翻不完"
          - alert: MoviePilotBrushAddStalled
            expr: moviepilot_brush_runs_found == 1 and moviepilot_brush_last_add_hours > 12
            for: 30m
            labels:
              severity: warning
            annotations:
              summary: "刷流已 {{ printf \"%.0f\" $value }} 小时没有新增下载，检查任务保种上限与全局删种阈值"
          - alert: MoviePilotBrushDeleteStalled
            expr: moviepilot_brush_runs_found == 1 and moviepilot_brush_last_delete_hours > 72
            for: 1h
            labels:
              severity: warning
            annotations:
              summary: "刷流已 {{ printf \"%.0f\" $value }} 小时没有删种，检查全局动态删种阈值是否仍能触发"
  '';
in
{
  services.prometheus.ruleFiles = [
    (pkgs.writeText "moviepilot-rules.yaml" rules)
  ];
}
