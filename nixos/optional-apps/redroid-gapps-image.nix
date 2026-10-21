# reDroid GApps 镜像构建（MindTheGapps 官方包叠加到基础 redroid 镜像）。
#
# 官方 redroid 镜像因 Google 版权限制不含 GMS（remote-android/redroid-doc
# 「GMS Support」章节），标准做法是把 MindTheGapps 的 system/ 树 COPY 到
# 基础镜像的 /system/ 上（redroid-doc issue #887）。redroid 13 镜像的
# /product 是指向 /system/product 的符号链接，MTG 包内 system/product/...
# 结构恰好落位，无需额外映射。
#
# 构建产物是本地 podman 镜像（不在 immutable closure 内），容器改用该镜像
# 并把 autoupdate 策略切到 local。更新 MTG 包时需同步升级 targetImage 的
# tag，否则已有旧 tag 镜像会被直接复用。
{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.lantian.redroidGappsImage = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Build a GApps-stacked redroid image and point the redroid container at it.";
    };
    baseImage = lib.mkOption {
      type = lib.types.str;
      default = "docker.io/redroid/redroid:13.0.0-latest";
      description = "Base redroid image (must be present locally or pullable via configured mirrors).";
    };
    targetImage = lib.mkOption {
      type = lib.types.str;
      default = "localhost/redroid13-gapps:13.0.0-mtg20231025";
      description = "Local image tag for the GApps-stacked image.";
    };
    mtgZip = lib.mkOption {
      type = lib.types.either lib.types.package lib.types.path;
      description = "MindTheGapps release zip (fetchurl-pinned).";
    };
  };

  config = lib.mkIf config.lantian.redroidGappsImage.enable {
    # 作用于既有 redroid 容器（本舰队各 redroid 模块的容器统一叫 redroid），
    # 只换镜像与 autoupdate 策略，端口/volume/cmd 仍由各 redroid 模块定义。
    virtualisation.oci-containers.containers.redroid.image =
      lib.mkForce config.lantian.redroidGappsImage.targetImage;
    virtualisation.oci-containers.containers.redroid.labels."io.containers.autoupdate" =
      lib.mkForce "local";

    systemd.services.redroid-gapps-image = {
      description = "Build the GApps-stacked redroid image (MindTheGapps overlay)";
      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        # 解压后的 system/ 树约 1G，不能用 RuntimeDirectory（tmpfs）。
        StateDirectory = "redroid-gapps-image";
        TimeoutStartSec = 900;
      };
      script = ''
                set -eu
                if ! ${pkgs.podman}/bin/podman image exists ${config.lantian.redroidGappsImage.baseImage}; then
                  ${pkgs.podman}/bin/podman pull ${config.lantian.redroidGappsImage.baseImage}
                fi
                if ${pkgs.podman}/bin/podman image exists ${config.lantian.redroidGappsImage.targetImage}; then
                  echo "${config.lantian.redroidGappsImage.targetImage} already exists"
                  exit 0
                fi
                ${pkgs.coreutils}/bin/rm -rf /var/lib/redroid-gapps-image/*
                ${pkgs.unzip}/bin/unzip -q ${config.lantian.redroidGappsImage.mtgZip} 'system/*' -d /var/lib/redroid-gapps-image
                cat > /var/lib/redroid-gapps-image/Containerfile <<'EOF'
        FROM ${config.lantian.redroidGappsImage.baseImage}
        COPY system/ /system/
        EOF
                ${pkgs.podman}/bin/podman build -t ${config.lantian.redroidGappsImage.targetImage} /var/lib/redroid-gapps-image
                ${pkgs.coreutils}/bin/rm -rf /var/lib/redroid-gapps-image/*
      '';
    };

    systemd.services.podman-redroid = {
      requires = [ "redroid-gapps-image.service" ];
      after = [ "redroid-gapps-image.service" ];
    };
  };
}
