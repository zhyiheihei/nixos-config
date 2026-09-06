# 复刻上游私有 ltnet-scripts 管线的投递端：主控机（= 作者的工作机角色）定时
# 从私有 ltnet-scripts 仓（zhyiheihei/ltnet-scripts，zones/ 主区 + ROA 下载脚本）
# 同步并推送到 rsync 源站 greencloud:/nix/sync-servers/ltnet-scripts/，随既有的
# rsync-nix-sync-servers（每 10 分钟）分发全舰队。
#
# 生成方式对齐作者博客《How to Kill the DN42 Network》的推荐：ROA 从 dn42 wiki
# Bird2 页面引用的官方端点下载并 cron 自动更新（脚本在私有仓 scripts/sync.sh）。
# greencloud 侧无需任何拉取服务，保持 rsync-server.nix 的纯源站形态（与上游
# Colocrossing 一致）。
{
  pkgs,
  ...
}:
{
  systemd.services.ltnet-scripts-sync = {
    description = "Sync private ltnet-scripts repo and push ROA/zones to the rsync primary";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      User = "zhyi";
      ExecStart = "${pkgs.bash}/bin/bash /home/zhyi/Documents/nixos/ltnet-scripts/scripts/sync.sh";
    };
    path = [
      pkgs.git
      pkgs.curl
      pkgs.rsync
      pkgs.openssh
    ];
  };

  systemd.timers.ltnet-scripts-sync = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "hourly";
      RandomizedDelaySec = "5min";
      Unit = "ltnet-scripts-sync.service";
    };
  };
}
