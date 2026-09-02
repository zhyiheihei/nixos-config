{ ... }:
# LibreChat 依赖的 MongoDB。
#
# 历史说明：2026-09-02 前用 services.mongodb（nixpkgs 源码构建）。nixpkgs
# mongodb 没有 aarch64 二进制缓存，源码编译先后压垮 opi5p（nix-daemon OOM
# 失联）与 dragon-q8b（boost/cc1plus 被 OOM kill）。本模块随 LibreChat 服务
# （greencloud → opi5p，2026-08-31）迁移后仅在 aarch64 主机使用，故改为官方
# 多架构容器镜像；mongosh 可用 `podman exec -it mongodb mongosh` 替代。
#
# 与原部署（services.mongodb bind_ip=127.0.0.1，无鉴权）等价：端口仅映射到
# 本机回环，且镜像未设置 MONGO_INITDB_ROOT_PASSWORD 时同样无鉴权。
{
  virtualisation.oci-containers.containers.mongodb = {
    image = "mongo:7.0";
    labels."io.containers.autoupdate" = "registry";
    ports = [ "127.0.0.1:27017:27017" ];
    volumes = [ "/var/lib/mongodb:/data/db" ];
  };

  # mongo:7.0 容器内 mongod 以 uid/gid 999 运行，bind mount 需预先对齐属主。
  systemd.tmpfiles.settings.mongodb = {
    "/var/lib/mongodb"."d" = {
      mode = "0750";
      user = "999";
      group = "999";
    };
  };

  lantian.preservation.directories = [ "/var/lib/mongodb" ];
}
