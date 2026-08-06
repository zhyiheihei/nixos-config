{
  lib,
  pkgs,
  ...
}:
let
  # Chinese titles that PT trackers actually match.  Add new entries here when
  # an English-only Sonarr search misses releases on M-Team / PTTime.
  mappings = [
    {
      tvdbId = 84802;
      searchTerm = "料理仙姬";
      parseTerm = "料理仙姬";
      title = "Osen";
      comment = "Manual Chinese alias for M-Team/PTTime";
    }
  ];

  insertStatements = lib.concatMapStringsSep "\n" (mapping: ''
    INSERT OR IGNORE INTO SceneMappings
      (TvdbId, SearchTerm, ParseTerm, Title, Type, SearchMode, Comment)
    SELECT ${toString mapping.tvdbId}, '${mapping.searchTerm}', '${mapping.parseTerm}',
           '${mapping.title}', 'XemService', -1, '${mapping.comment}'
    WHERE NOT EXISTS (
      SELECT 1 FROM SceneMappings
      WHERE TvdbId = ${toString mapping.tvdbId}
        AND SearchTerm = '${mapping.searchTerm}'
    );
  '') mappings;
in
{
  systemd.services.sonarr-chinese-scene-mappings = {
    description = "Insert Sonarr scene mappings for Chinese PT search terms";
    wantedBy = [ "sonarr.service" ];
    after = [ "sonarr.service" ];
    path = [ pkgs.sqlite ];
    script = ''
      db=/var/lib/sonarr/sonarr.db
      [ -f "$db" ] || exit 0
      ${pkgs.sqlite}/bin/sqlite3 "$db" <<'SQL'
${insertStatements}
SQL
    '';
    serviceConfig = {
      Type = "oneshot";
      User = "zhyi";
      Group = "users";
    };
  };
}
