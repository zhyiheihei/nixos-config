#!/usr/bin/env bash
# 单变量门控：检查 hosts/<host>/ 与 nixos/ 的未提交改动规模，超限直接拒绝。
# 用法：tools/host-change-gate.sh [hostname]
set -euo pipefail
host="${1:-venus}"
max_files="${MAX_FILES:-1}"
max_lines="${MAX_LINES:-15}"

cd "$(dirname "$0")/.."

mapfile -t files < <(git diff --name-only HEAD -- "hosts/$host" nixos/ | grep -v 'flake.lock' || true)
if [ "${#files[@]}" -eq 0 ]; then
  echo "门控：hosts/$host 与 nixos/ 无改动"
  exit 0
fi

added=$(git diff --numstat HEAD -- "hosts/$host" nixos/ | awk '{a+=$1} END{print a+0}')
removed=$(git diff --numstat HEAD -- "hosts/$host" nixos/ | awk '{r+=$2} END{print r+0}')
total=$((added + removed))

echo "门控：改动文件 ${#files[@]} 个，增 $added / 删 $removed 行（共 $total 行）"
printf '  %s\n' "${files[@]}"

fail=0
[ "${#files[@]}" -gt "$max_files" ] && {
  echo "拒绝：文件数超过 $max_files"
  fail=1
}
[ "$total" -gt "$max_lines" ] && {
  echo "拒绝：变更行数超过 $max_lines"
  fail=1
}
[ "$fail" -ne 0 ] && {
  echo "如确需更大改动，显式设 ALLOW_LARGE_CHANGE=1 并说明理由"
  [ "${ALLOW_LARGE_CHANGE:-0}" = "1" ] || exit 1
}
echo "门控通过"
