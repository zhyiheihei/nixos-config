# 复刻上游私有 ltnet-scripts 管线中本 fork 实际消费的部分，落在 rsync 源站
# （greencloud），经既有的 rsync-nix-sync-servers（每 10 分钟）分发全舰队。
#
# 架构对齐上游：上游作者的私有 ltnet-scripts 仓（不公开）+ 公共 nixos-config。
# 我们的同名私有仓 = zhyiheihei/ltnet-scripts（zones/ 手工维护的主区文件），
# 本服务把它 clone/pull 到 /nix/sync-servers/ltnet-scripts（rsync 直接服务该
# 目录，与上游布局一致），并生成 ROA 产物到 bird/（.gitignore 排除）。
#
# ROA 数据源：burble（dn42regsrv）与 kioubit（registry wizard）的官方公开聚合
# JSON，均 v4+v6 合一，stayrtr 默认即 gortr JSON 无需转换。burble 的 clearnet
# 镜像偶发滞后 >24h（stayrtr checktime 会拒收），故 kioubit 为主、burble 兜底。
#
# 消费关系：stayrtr 读 bird/dn42/dn42_stayrtr.conf（gortr JSON，bird 经 RTR 协议
# 消费，本 fork 的 bird 配置不直接 include roa conf，bird2 conf 仅保持目录结构
# 对齐上游）；knot/coredns 读 zones/*.zone。NeoNetwork ROA 不生成：本 fork 无
# 任何消费者（无 NEO 标签主机、stayrtr 无实例）。ltnet-registry 刷新待后续。
{
  pkgs,
  lib,
  config,
  inputs,
  ...
}:
let
  repo = "git@github.com:zhyiheihei/ltnet-scripts.git";
  repoDir = "/nix/sync-servers/ltnet-scripts";
  jsonUrls = [
    "https://kioubit-roa.dn42.dev/?type=json"
    "https://dn42.burble.com/roa/dn42_roa_46.json"
  ];
  bird2V4Urls = [
    "https://kioubit-roa.dn42.dev/?type=v4"
    "https://dn42.burble.com/roa/dn42_roa_bird2_4.conf"
  ];
  bird2V6Urls = [
    "https://kioubit-roa.dn42.dev/?type=v6"
    "https://dn42.burble.com/roa/dn42_roa_bird2_6.conf"
  ];

  script = pkgs.writeShellScript "ltnet-scripts-sync" ''
    set -euo pipefail
    umask 022
    export HOME=/root
    export GIT_SSH_COMMAND="ssh -i ${config.sops.secrets.ltnet-scripts-deploy-key.path} -o StrictHostKeyChecking=accept-new -o BatchMode=yes"

    # 同步私有 ltnet-scripts 仓（zones/ 主区文件）
    if [ ! -d ${repoDir}/.git ]; then
      # bootstrap 遗留目录（占位/旧产物，内容均可再生）：移开后再克隆
      if [ -d ${repoDir} ] && [ -n "$(ls -A ${repoDir} 2>/dev/null)" ]; then
        mv ${repoDir} "${repoDir}.bak-$(date +%s)"
      fi
      mkdir -p ${repoDir}
      git clone --depth 1 ${repo} ${repoDir}
    else
      git -C ${repoDir} fetch origin main
      git -C ${repoDir} reset --hard origin/main
    fi
    mkdir -p ${repoDir}/bird/dn42

    # 多源尝试：任一 URL 成功即用
    fetch_first() {
      for url in "$@"; do
        if ${pkgs.curl}/bin/curl -fsS --max-time 60 "$url" -o "$tmp"; then return 0; fi
      done
      return 1
    }

    tmp=$(mktemp)
    trap 'rm -f "$tmp"' EXIT

    # stayrtr cache（gortr JSON）；结构校验失败保留旧文件
    if fetch_first ${lib.concatStringsSep " " jsonUrls}; then
      if ${pkgs.jq}/bin/jq -e '.roas | type == "array"' "$tmp" >/dev/null; then
        install -m 644 "$tmp" ${repoDir}/bird/dn42/dn42_stayrtr.conf
      fi
    fi

    # bird2 roa conf：v4/v6 各一份，直接取官方产物
    fetch_first ${lib.concatStringsSep " " bird2V4Urls} \
      && install -m 644 "$tmp" ${repoDir}/bird/dn42/dn42_bird2_roa4.conf
    fetch_first ${lib.concatStringsSep " " bird2V6Urls} \
      && install -m 644 "$tmp" ${repoDir}/bird/dn42/dn42_bird2_roa6.conf
  '';
in
{
  sops.secrets.ltnet-scripts-deploy-key = {
    sopsFile = inputs.secrets + "/common/ltnet-scripts-deploy-key.yaml";
    mode = "0400";
  };

  systemd.services.ltnet-scripts-sync = {
    description = "Sync private ltnet-scripts repo and refresh dn42 ROA on the rsync primary";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = script;
    };
    path = [
      pkgs.git
      pkgs.curl
      pkgs.jq
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
