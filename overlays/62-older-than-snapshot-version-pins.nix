# 搬运 nixpkgs 6510408d 的两包，修复 2026-10-14 wave 部署后被锁回
# 151fa4e8 的「数据库已迁新版、二进制却是旧版」降级拒绝：
# - immich：opi5p 库已迁 3.3.1，151fa4e8 的 3.2.4 启动即报 corrupted
#   migrations / Downgrades are not supported，crash-loop（restart counter 2000+）
# - gitea：greencloud-jp 库已迁 358（28.1.0），151fa4e8 的 28.0.0（356）
#   拒启 Migration Error
# - pocket-id：volcengine 库已迁 20260929120000（2.18.0），151fa4e8 的
#   2.16.0（20260916120000）拒启 downgrades are not allowed
# 锁升级越过 6510408d 后删本文件。
_: final: prev:
let
  nixpkgs6510408d = import (builtins.fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/6510408d147d.tar.gz";
    sha256 = "012w2z2w4k0c3kg9hcy9cpd7qgxgrpxvf0735vy014r7x9qhmbjw";
  }) { localSystem = prev.system; };
in
{
  inherit (nixpkgs6510408d) immich;
  inherit (nixpkgs6510408d) immich-machine-learning;
  inherit (nixpkgs6510408d) gitea;
  inherit (nixpkgs6510408d) pocket-id;
}
