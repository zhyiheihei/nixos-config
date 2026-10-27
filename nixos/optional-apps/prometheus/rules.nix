# 停摆类告警（textfile 指标，经 Alertmanager 走 Telegram）：
# - rock5c moviepilot-watchdog：订阅搜索卡死 / 刷流新增、删种停摆
# - opi5p epd-food-server：食品看板推送停摆与连续传输失败
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
      - name: epd-food
        rules:
          - alert: EpdFoodPanelPushStalled
            expr: epd_food_last_success_timestamp_seconds > 0 and time() - epd_food_last_success_timestamp_seconds > 43200
            for: 30m
            labels:
              severity: warning
            annotations:
              summary: "食品看板墨水屏已超过 12 小时没有成功推送，检查 last-failure.json 的失败阶段与 push-retry.json"
          - alert: EpdFoodPanelPushFailing
            expr: epd_food_push_failures >= 4
            for: 10m
            labels:
              severity: warning
            annotations:
              summary: "食品看板推送连续失败 {{ $value }} 次（退避重试已进行约 2 小时），设备可能断电或超出蓝牙范围"
  '';
in
{
  services.prometheus.ruleFiles = [
    (pkgs.writeText "stall-rules.yaml" rules)
  ];
}
