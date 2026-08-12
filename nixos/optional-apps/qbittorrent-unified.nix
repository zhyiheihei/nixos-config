{
  config,
  lib,
  LT,
  pkgs,
  ...
}:
let
  cfg = config.lantian.qbittorrent-unified;

  qbitPreStart = ''
    conf=${cfg.profileDir}/qBittorrent/config/qBittorrent.conf
    mkdir -p "$(dirname "$conf")"
    touch "$conf"
    if ! grep -q '^\[BitTorrent\]$' "$conf"; then
      printf '[BitTorrent]\n' >> "$conf"
    fi
    if ! grep -q '^\[Preferences\]$' "$conf"; then
      printf '[Preferences]\n' >> "$conf"
    fi
    sed -i '/^Session\\DefaultSavePath=/d' "$conf"
    sed -i '/^Session\\Interface=/d' "$conf"
    sed -i '/^Session\\InterfaceName=/d' "$conf"
    sed -i '/^Session\\InterfaceAddress=/d' "$conf"
    sed -i '/^WebUI\\AuthSubnetWhitelistEnabled=/d' "$conf"
    sed -i '/^WebUI\\AuthSubnetWhitelist=/d' "$conf"
    sed -i "/^\[BitTorrent\]$/a Session\\\\DefaultSavePath=${cfg.downloadPath}/" "$conf"
    ${lib.optionalString (cfg.networkInterface != null) ''
      sed -i "/^\[BitTorrent\]$/a Session\\\\Interface=${cfg.networkInterface}" "$conf"
      sed -i "/^\[BitTorrent\]$/a Session\\\\InterfaceName=${cfg.networkInterface}" "$conf"
    ''}
    ${lib.optionalString (cfg.authSubnetWhitelist != [ ]) ''
      sed -i '/^\[Preferences\]$/a WebUI\\AuthSubnetWhitelistEnabled=true' "$conf"
      sed -i "/^\[Preferences\]$/a WebUI\\AuthSubnetWhitelist=${builtins.concatStringsSep "," cfg.authSubnetWhitelist}" "$conf"
    ''}
  '';
in
{
  imports = [
    ./qbittorrent.nix
    ./qbittorrent-pt.nix
    ./qbittorrent-seedbox.nix
    ../optional-cron-jobs/qbittorrent-pt-cleanup
  ];

  options.lantian.qbittorrent-unified = {
    enable = lib.mkEnableOption "the unified single qBittorrent client";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.qbittorrent-nox;
      description = "qBittorrent package used by the unified client. PT trackers generally require the official client, not the enhanced fork.";
    };

    profileDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/qbittorrent";
      description = "qBittorrent profile directory.";
    };

    webuiPort = lib.mkOption {
      type = lib.types.port;
      default = LT.port.qBitTorrent.WebUI;
      description = "WebUI port for the unified client.";
    };

    torrentingPort = lib.mkOption {
      type = lib.types.port;
      default = LT.this.wg-zhyi.forwardStart;
      description = "Inbound torrenting port for the unified client.";
    };

    downloadPath = lib.mkOption {
      type = lib.types.str;
      default = "/mnt/storage/downloads";
      description = "Default save path written into qBittorrent Session\\DefaultSavePath.";
    };

    networkInterface = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "qBittorrent Session\\Interface. PT trackers reject announces from multiple interfaces, so bind the WAN interface.";
    };

    authSubnetWhitelist = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "LAN hosts or subnets allowed to bypass WebUI authentication.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.qbittorrent = {
      enable = lib.mkForce true;
      package = lib.mkForce cfg.package;
      user = lib.mkForce "zhyi";
      group = lib.mkForce "users";
      profileDir = lib.mkForce cfg.profileDir;
      webuiPort = lib.mkForce cfg.webuiPort;
      torrentingPort = lib.mkForce cfg.torrentingPort;
      extraArgs = lib.mkForce [ "--confirm-legal-notice" ];
    };

    systemd.services = {
      qbittorrent.preStart = lib.mkAfter qbitPreStart;
      # Legacy multi-instance units remain defined for rollback, but the
      # unified client owns all download work while this module is enabled.
      qbittorrent-pt.enable = lib.mkForce false;
      qbittorrent-seedbox.enable = lib.mkForce false;
    };

    systemd.timers.qbittorrent-pt-cleanup.enable = lib.mkForce false;

    lantian.qbittorrent-seedbox.downloadPath = cfg.downloadPath;
  };
}
