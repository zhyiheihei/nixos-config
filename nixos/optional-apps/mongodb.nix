# LibreChat 依赖的 MongoDB。
#
# 历史说明：2026-09-02 曾短暂改用官方多架构容器镜像（mongo:7.0），因为
# nixpkgs mongodb 无 aarch64 二进制缓存，源码编译在 aarch64 主机上反复
# OOM。随 LibreChat 迁回 greencloud（x86_64，store 里保留有迁移前构建的
# mongodb 7.0.39）后恢复 services.mongodb；aarch64 主机不要导入本模块。
{
  pkgs,
  config,
  ...
}:
{
  services.mongodb = {
    enable = true;
    bind_ip = "127.0.0.1";
    package = pkgs.mongodb;
  };
  environment.systemPackages = [
    pkgs.mongosh
    pkgs.mongodb-tools
  ];
  lantian.preservation.directories = [
    {
      directory = config.services.mongodb.dbpath;
      user = "mongodb";
      group = "mongodb";
    }
  ];

  systemd.services.mongodb = {
    after = [ "var-db-mongodb.mount" ];
    requires = [ "var-db-mongodb.mount" ];

    serviceConfig = {
      Restart = "always";
      RestartSec = 5;
    };
  };
}
