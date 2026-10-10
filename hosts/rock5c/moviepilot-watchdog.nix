# MoviePilot 健康度看门狗：把两类已实锤的停摆状态（订阅搜索队列卡死、
# 刷流新增/删种停摆）导出为 node_exporter textfile 指标，由 tencent
# Prometheus 告警（Alertmanager → Telegram）。故障背景与阈值依据见
# docs/agent/inspection-playbook.md 的 moviepilot 条目。
{
  pkgs,
  ...
}:
let
  metricsDir = "/var/lib/node-exporter-textfile";
  metricsFile = "${metricsDir}/moviepilot.prom";

  probe = pkgs.writeText "moviepilot-watchdog-probe.py" ''
    import json
    import sqlite3
    import time
    from datetime import datetime

    db = sqlite3.connect("file:/config/user.db?mode=ro", uri=True)
    now = time.time()

    stuck = db.execute(
        "SELECT COUNT(*) FROM subscriptionsearchtask "
        "WHERE state IN ('queued', 'running') AND attempt_count >= 20"
    ).fetchone()[0]

    runs_found = 0
    last_add = 0.0
    last_delete = 0.0
    rows = db.execute(
        "SELECT value FROM plugindata "
        "WHERE plugin_id = 'BrushFlow' AND key LIKE 'task.%.runs'"
    ).fetchall()
    for (raw,) in rows:
        try:
            runs = json.loads(raw)
        except (TypeError, ValueError):
            continue
        if runs:
            runs_found = 1
        for run in runs:
            started = run.get("started_at")
            if not started:
                continue
            try:
                ts = datetime.fromisoformat(started).timestamp()
            except ValueError:
                continue
            if run.get("kind") == "brush" and (run.get("added_count") or 0) > 0:
                last_add = max(last_add, ts)
            if run.get("kind") == "check":
                deleted = (run.get("deleted_count") or 0) + (run.get("global_deleted_count") or 0)
                if deleted > 0:
                    last_delete = max(last_delete, ts)

    def hours_since(ts):
        if ts:
            return (now - ts) / 3600
        # 窗口内一次都没有：有运行历史时视为持续停摆（999），
        # 无运行历史（插件已移除/尚未运行）时视为未知（0，不告警）。
        return 999.0 if runs_found else 0.0

    print("# HELP moviepilot_subscribe_search_stuck_tasks Subscription search tasks stuck retrying.")
    print("# TYPE moviepilot_subscribe_search_stuck_tasks gauge")
    print(f"moviepilot_subscribe_search_stuck_tasks {stuck}")
    print("# HELP moviepilot_brush_runs_found Whether BrushFlow run history is readable.")
    print("# TYPE moviepilot_brush_runs_found gauge")
    print(f"moviepilot_brush_runs_found {runs_found}")
    print("# HELP moviepilot_brush_last_add_hours Hours since a brush run last added torrents.")
    print("# TYPE moviepilot_brush_last_add_hours gauge")
    print(f"moviepilot_brush_last_add_hours {hours_since(last_add):.2f}")
    print("# HELP moviepilot_brush_last_delete_hours Hours since a check run last deleted torrents.")
    print("# TYPE moviepilot_brush_last_delete_hours gauge")
    print(f"moviepilot_brush_last_delete_hours {hours_since(last_delete):.2f}")
  '';

  watchdog = pkgs.writeShellScript "moviepilot-watchdog" ''
    set -euo pipefail
    metrics=$(${pkgs.podman}/bin/podman exec -i moviepilot python3 - < ${probe})
    tmp=$(${pkgs.coreutils}/bin/mktemp ${metricsDir}/.moviepilot.XXXXXX)
    printf '%s\n' "$metrics" > "$tmp"
    ${pkgs.coreutils}/bin/chmod 644 "$tmp"
    ${pkgs.coreutils}/bin/mv "$tmp" ${metricsFile}
  '';
in
{
  systemd.services.moviepilot-watchdog = {
    description = "Export MoviePilot brush/subscribe health metrics";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = watchdog;
      ReadWritePaths = [ metricsDir ];
      Restart = "on-failure";
    };
  };

  systemd.timers.moviepilot-watchdog = {
    description = "Refresh MoviePilot health metrics";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "3min";
      OnUnitActiveSec = "5min";
      Unit = "moviepilot-watchdog.service";
    };
  };
}
