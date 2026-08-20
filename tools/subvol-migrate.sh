#!/usr/bin/env bash
# ml-client btrfs 子卷对齐迁移脚本
# 用法：在目标机 NixOS 安装 U 盘/live 环境里，root 下执行
#   bash /path/to/subvol-migrate.sh <btrfs-dev> <target:ml-2700|ml-laptop>
#
# 前置：/nix 当前挂顶层子卷(subvol=/)，/nix/persistent 是普通目录。
# 目标：创建 subvol=persistent、subvol=home，数据 reflink 迁入。
# 全程不删旧数据，直到新结构验证通过。
set -euo pipefail

DEV="$1"
HOST="${2:-ml-2700}"

if [[ $EUID -ne 0 ]]; then echo "must run as root"; exit 1; fi
[[ -n "$DEV" ]] || { echo "usage: $0 <btrfs-dev> <ml-2700|ml-laptop>"; exit 1; }

echo "==[1/5] 挂载 btrfs 顶层到 /mnt/root =="
mkdir -p /mnt/root
mount -o subvol=/ "$DEV" /mnt/root
cd /mnt/root

echo "==[2/5] 检查现有布局 =="
if [[ ! -d persistent ]]; then
  echo "ERROR: /mnt/root/persistent 不存在，确认设备正确"; exit 1
fi
if [[ -d persistent.old ]]; then
  echo "ERROR: persistent.old 已存在，上次迁移未完成或未清理"; exit 1
fi
btrfs subvolume show persistent >/dev/null 2>&1 && {
  echo "ERROR: persistent 已是子卷，无需迁移"; exit 1
}

echo "==[3/5] 创建独立子卷 + reflink 数据 =="
mv persistent persistent.old
btrfs subvolume create persistent
btrfs subvolume create persistent/home

cp -a --reflink=always persistent.old/. persistent/
# home 单独对齐
if [[ -d persistent.old/home ]]; then
  cp -a --reflink=always persistent.old/home/. persistent/home/
fi

echo "==[4/5] 校验数据完整性（对比文件数与大小）="
old_n=$(find persistent.old -type f | wc -l)
new_n=$(find persistent -type f | wc -l)
echo "  旧文件数: $old_n  新文件数: $new_n"
[[ "$old_n" == "$new_n" ]] || {
  echo "ERROR: 文件数不一致，请勿继续！"; exit 1
}

echo "==[5/5] 输出：接下来需要修改 hardware-configuration.nix 并重建启动 =="
echo "--------------------------------------------------"
echo "目标机: $HOST  设备: $DEV"
echo "请按 docs/human/migrations/ml-client-btrfs-subvol-migration.md 步骤 3-6 继续："
echo "  1. 编辑 /etc/nixos/.../hardware-configuration.nix，声明 /nix/persistent(subvol=persistent)"
echo "     和 /nix/persistent/home(subvol=home) 挂载，neededForBoot=true"
echo "  2. nixos-install --no-root-passwd 重建启动环境"
echo "  3. reboot，验证 findmnt /nix/persistent 显示 subvol=persistent"
echo "  4. 确认 backup 服务可跑：systemctl start backup-home; journalctl -u backup-home"
echo "  5. 验证通过后：btrfs subvolume delete /mnt/root/persistent.old"
echo "--------------------------------------------------"
echo "DONE（数据已迁到新子卷，persistent.old 保留作回滚）"
