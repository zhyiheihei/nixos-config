# 复刻上游私有 ltnet-scripts 管线中本 fork 实际消费的部分，落在 rsync 源站
# （greencloud），经既有的 rsync-nix-sync-servers（每 10 分钟）分发全舰队。
#
# 上游原管线在作者的私有 ltnet-scripts 仓库（不公开），产出四类文件：
#   1. dn42_stayrtr.conf  → stayrtr --cache（gortr JSON 格式，bird 经 RTR 消费）
#   2. bird2 roa conf × 4 → 本 fork 的 bird 配置（config/sys.nix 的 sys.roa）只走
#      RTR 协议、不 include 这些文件，但为保持 /nix/sync-servers 目录结构与上游
#      一致，仍按上游格式生成
#   3. knot/coredns 主区文件（ltnet-scripts/zones/）→ 上游手工维护的私有 zone
#   4. ltnet-registry（dn42 registry 快照）→ 本机已有 bootstrap 快照，刷新待后续
# NeoNetwork ROA 不生成：本 fork 无任何消费者（无 NEO 标签主机、stayrtr 无实例）。
# ROA 数据源用 burble（dn42regsrv）的官方公开聚合 JSON，v4+v6 合一，stayrtr 默认
# 就是 gortr JSON 格式，无需转换。
{
  pkgs,
  ...
}:
let
  roaJson = "https://dn42.burble.com/roa/dn42_roa_46.json";
  dn42Dir = "/nix/sync-servers/ltnet-scripts/bird/dn42";
  zonesDir = "/nix/sync-servers/ltnet-scripts/zones";

  # 静态主区文件：上游放私有仓，我们内置在配置里。
  # SOA 参数对齐 dns/common/nameservers.nix 的 common.soa.DN42。
  telZone = pkgs.writeText "tel.dn42.zone" ''
    $ORIGIN tel.dn42.
    $TTL 3600
    @ 3600 IN SOA ns1.zhyi.dn42. molishanguang.outlook.com. (
      2026090601 360 600 604800 600 )
    @ 3600 IN NS ns1.zhyi.dn42.
    ; 子区 7.4.5.2.4.2.4.0.tel.dn42 由 dnscontrol 发布到 ltnet-zones，
    ; 委托指向我们的 dn42 权威 NS。
    7.4.5.2.4.2.4.0 3600 IN NS ns1.zhyi.dn42.
  '';
  asnZhyiDn42Zone = pkgs.writeText "asn.zhyi.dn42.zone" ''
    $ORIGIN asn.zhyi.dn42.
    $TTL 3600
    @ 3600 IN SOA ns1.zhyi.dn42. molishanguang.outlook.com. (
      2026090601 360 600 604800 600 )
    @ 3600 IN NS ns1.zhyi.dn42.
  '';
  asnZhyiCcZone = pkgs.writeText "asn.zhyi.cc.zone" ''
    $ORIGIN asn.zhyi.cc.
    $TTL 3600
    @ 3600 IN SOA ns1.zhyi.dn42. molishanguang.outlook.com. (
      2026090601 360 600 604800 600 )
    @ 3600 IN NS ns1.zhyi.dn42.
  '';

  script = pkgs.writeShellScript "ltnet-scripts-sync" ''
    set -euo pipefail
    umask 022
    mkdir -p ${dn42Dir} ${zonesDir}

    # ROA JSON（gortr 格式）原子更新；失败保留旧文件，stayrtr 继续用旧数据
    tmp=$(mktemp)
    trap 'rm -f "$tmp" "$tmp.v4" "$tmp.v6"' EXIT
    ${pkgs.curl}/bin/curl -fsS --max-time 60 ${roaJson} -o "$tmp"
    ${pkgs.jq}/bin/jq -e '.roas | type == "array"' "$tmp" >/dev/null
    install -m 644 "$tmp" ${dn42Dir}/dn42_stayrtr.conf

    # bird2 roa conf：v4/v6 各一份，格式 = bird2 "roa table" 语句体
    ${pkgs.jq}/bin/jq -r '.roas[] | select(.prefix | test(":") | not)
      | "route \(.prefix) max \(.maxLength) as \(.asn | ltrimstr("AS"));"' \
      "$tmp" | install -m 644 /dev/stdin ${dn42Dir}/dn42_bird2_roa4.conf
    ${pkgs.jq}/bin/jq -r '.roas[] | select(.prefix | test(":"))
      | "route \(.prefix) max \(.maxLength) as \(.asn | ltrimstr("AS"));"' \
      "$tmp" | install -m 644 /dev/stdin ${dn42Dir}/dn42_bird2_roa6.conf

    install -m 644 ${telZone} ${zonesDir}/tel.dn42.zone
    install -m 644 ${asnZhyiDn42Zone} ${zonesDir}/asn.zhyi.dn42.zone
    install -m 644 ${asnZhyiCcZone} ${zonesDir}/asn.zhyi.cc.zone
  '';
in
{
  systemd.services.ltnet-scripts-sync = {
    description = "Refresh dn42 ROA and ltnet-scripts zone files on the rsync primary";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = script;
    };
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
