{
  pkgs,
  lib,
  LT,
  ...
}:
let
  qbitAddress = LT.hosts.router.interconnect.IPv4;
  nexusphpPlugin = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/Juszoe/flexget-nexusphp/master/nexusphp.py";
    sha256 = "0shbdx2z7dn9bn08y4y2fpxdd2281nr7ifqr31bxarmk57srdlxm";
  };
  flexgetTemplate = pkgs.writeText "flexget-router.yml" (
    builtins.toJSON {
      templates = {
        downloads = {
          qbittorrent = {
            path = "/mnt/storage/downloads";
            host = qbitAddress;
            port = LT.port.qBitTorrentPT.WebUI;
            username = "$QBITTORRENT_USERNAME";
            password = "$QBITTORRENT_PASSWORD";
            label = "flexget";
          };
          free_space = {
            path = "/mnt/storage/downloads";
            space = 2 * 1024 * 1024; # 2TB
          };
        };
        downloads-auto = {
          qbittorrent = {
            path = "/mnt/storage/.downloads-auto";
            host = qbitAddress;
            port = LT.port.qBitTorrentPT.WebUI;
            username = "$QBITTORRENT_USERNAME";
            password = "$QBITTORRENT_PASSWORD";
            label = "flexget-auto";
          };
          free_space = {
            path = "/mnt/storage/.downloads-auto";
            space = 200 * 1024; # 200GB
          };
        };
      };
      tasks = {
        hdhome-auto = {
          limit = {
            amount = 1;
            from.rss = "$HDHOME_AUTO_RSS_URL";
          };
          seen.fields = [ "url" ];
          accept_all = true;
          template = "downloads-auto";
        };
      };
    }
  );
in
{
  # qBittorrent now runs on router. Keep the old units defined but disabled so
  # the automation consumers can be cut over without removing module imports.
  systemd.services = {
    qbittorrent.enable = lib.mkForce false;
    qbittorrent-pt.enable = lib.mkForce false;
    qbittorrent-seedbox.enable = lib.mkForce false;
    qbittorrent-pt-cleanup.enable = lib.mkForce false;

    flexget-runner.script = lib.mkForce ''
      if test -z "''${HDHOME_AUTO_RSS_URL:-}"; then
        echo "HDHOME_AUTO_RSS_URL is not configured; skipping FlexGet run"
        exit 0
      fi

      cat ${flexgetTemplate} | ${lib.getExe pkgs.envsubst} > flexget.yml

      mkdir -p plugins
      ln -sf ${nexusphpPlugin} plugins/nexusphp.py

      ${lib.getExe' pkgs.flexget "flexget"} -c flexget.yml backlog clear
      ${lib.getExe' pkgs.flexget "flexget"} -c flexget.yml failed clear
      exec ${lib.getExe' pkgs.flexget "flexget"} -c flexget.yml execute
    '';
  };

  systemd.timers.qbittorrent-pt-cleanup.enable = lib.mkForce false;
}
