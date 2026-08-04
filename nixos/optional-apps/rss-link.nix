{
  LT,
  config,
  inputs,
  ...
}:
{
  sops.secrets = {
    miniflux-api-key = {
      sopsFile = inputs.secrets + "/common/personal-apps.yaml";
      key = "MINIFLUX_API_KEY";
    };
    linkwarden-api-token = {
      sopsFile = inputs.secrets + "/common/personal-apps.yaml";
      key = "LINKWARDEN_API_TOKEN";
    };
  };

  # RSS 自动化链路（Miniflux 星标 → Linkwarden 书签 → ArchiveBox 归档）
  systemd.services.rss-link-sync = {
    description = "Sync Miniflux starred items to Linkwarden, archive new bookmarks via ArchiveBox";
    after = [ "network-online.target" "podman-archivebox.service" "podman-linkwarden.service" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      User = "root";
    };
    environment = {
      MINIFLUX_BASE = "https://rss.zhyi.xin/v1";
      LINKWARDEN_API = "http://127.0.0.1:${LT.portStr.Linkwarden}/api/v1";
    };
    script = ''
      set -eu
      MINIFLUX_KEY=$(cat ${config.sops.secrets.miniflux-api-key.path})
      LINKWARDEN_TOKEN=$(cat ${config.sops.secrets.linkwarden-api-token.path})

      # --- 1. Miniflux 星标 → Linkwarden 书签 ---
      existing_urls=$(curl -fsS --max-time 30 -H "Authorization: Bearer $LINKWARDEN_TOKEN" \
        "$LINKWARDEN_API/bookmarks" 2>/dev/null | jq -r '.response.bookmarks[].url // empty' 2>/dev/null || true)

      curl -fsS --max-time 30 -H "X-Auth-Token: $MINIFLUX_KEY" \
        "$MINIFLUX_BASE/entries?starred=true&status=starred" 2>/dev/null \
      | jq -r '.entries[] | [.url, .title] | @tsv' 2>/dev/null \
      | while IFS=$'\t' read -r url title; do
          [ -z "$url" ] && continue
          if printf '%s\n' "$existing_urls" | grep -qxF "$url"; then
            continue
          fi
          curl -fsS --max-time 30 -X POST -H "Authorization: Bearer $LINKWARDEN_TOKEN" \
            -H "Content-Type: application/json" \
            -d "$(jq -cn --arg u "$url" --arg t "$title" '{ url: $u, name: $t, description: "auto-synced from Miniflux" }')" \
            "$LINKWARDEN_API/bookmarks" >/dev/null 2>&1 || true
        done

      # --- 2. Linkwarden 新书签 → ArchiveBox 归档 ---
      # ArchiveBox add 自身对重复 URL 会跳过，直接全量尝试。
      curl -fsS --max-time 30 -H "Authorization: Bearer $LINKWARDEN_TOKEN" \
        "$LINKWARDEN_API/bookmarks" 2>/dev/null \
      | jq -r '.response.bookmarks[].url // empty' 2>/dev/null \
      | while read -r url; do
          [ -z "$url" ] && continue
          podman exec archivebox archivebox add "$url" >/dev/null 2>&1 || true
        done
    '';
  };

  systemd.timers.rss-link-sync = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*:0/10";
      Persistent = true;
    };
  };
}
