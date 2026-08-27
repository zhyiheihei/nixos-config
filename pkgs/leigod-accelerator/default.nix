# 雷神加速器的 Linux 后台守护打包（无官方通用 Linux 桌面版；取用的是
# SteamDeck 插件渠道的路由级守护 acc-gw.router）。仓库内无上游可引，
# 移植参考 github.com/Husky0c/leigod-plugin-linux：
# - 二进制从雷神服务器固定地址获取，静态链接 x86_64 ELF，无需 patchelf；
# - 运行期以名字调用 iptables/ipset/curl，由模块的 systemd PATH 提供；
# - 服务端校验设备必须是 SteamDeck（Jupiter/SteamOS），伪装由模块完成。
{
  lib,
  stdenv,
  fetchurl,
}:
stdenv.mkDerivation {
  pname = "leigod-accelerator";
  version = "1.2.2.15";

  accBin = fetchurl {
    url = "http://119.3.40.126/acc-gw.router.amd64";
    hash = "sha256-jgrb0bHODTfmWI/yIkCP7Waj+JVP7ie8N6EOC/aAbU0=";
  };
  ipdb = fetchurl {
    url = "http://119.3.40.126/ipdatacloud_country.xdb";
    hash = "sha256-NTYADunrOZdTjLN6FPkNVxl5c0xIsjuNVI7OrBZmYnM=";
  };

  dontUnpack = true;
  dontBuild = true;

  installPhase = ''
    mkdir -p $out/share/leigod/config
    install -Dm755 $accBin $out/share/leigod/acc-gw.router.amd64
    # 升级监控与主程序同一二进制，靠进程名区分角色（与官方一致）
    ln -s acc-gw.router.amd64 $out/share/leigod/acc_upgrade_monitor
    install -Dm644 $ipdb $out/share/leigod/config/ipdatacloud_country.xdb
    # 官方安装包随附的静态配置模板，首次启动复制进状态目录后可被改写
    install -Dm644 ${./conf/accelerator.ini} $out/share/leigod/config/accelerator.ini
    install -Dm644 ${./conf/acc_version.ini} $out/share/leigod/config/acc_version.ini
    install -Dm644 ${./conf/new_upgrade_conf.json} $out/share/leigod/config/new_upgrade_conf.json
    touch $out/share/leigod/config/accelerator
  '';

  meta = {
    description = "Leigod game accelerator headless daemon (SteamDeck plugin binaries)";
    platforms = [ "x86_64-linux" ];
    license = lib.licenses.unfree;
  };
}
