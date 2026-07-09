# Attic 全量推送 /nix/store 操作手册

本文记录如何把缓存机 `ml-builder-cache` 上当前 `/nix/store` 里的所有 store path 手动推送到 Attic。

适用场景：

- `attic-watch-store.service` 已经能正常上传新路径，但历史失败项没有自动补齐。
- 刚修好 Attic/S3 后，需要把缓存机本地已有 store path 全量补推一次。
- 希望弱机器后续尽量从 `https://attic.zhyi.cc:4000/lantian` 拉缓存，而不是本地构建。

当前缓存链路：

```text
ml-builder-cache /nix/store
  -> attic push lantian
  -> https://attic.zhyi.cc:4000/lantian
  -> VaultS3 bucket nix-cache
```

## 1. 登录缓存机

```bash
ssh -A -p 2222 root@192.168.2.135
```

确认机器：

```bash
hostname
```

应该输出：

```text
ml-builder-cache
```

## 2. 建议使用 tmux

全量推送可能持续很久，建议放进 `tmux`：

```bash
nix shell nixpkgs#tmux -c tmux new -s attic-push-all
```

断开但不停止任务：

```text
Ctrl-b d
```

重新进入：

```bash
tmux attach -t attic-push-all
```

## 3. 登录 Attic

手动推送使用你自己的 `nixos-secrets` 里的 upload token。来源链路是：

```text
nixos-secrets/common/attic.yaml
  -> attic-upload-key
  -> sops-install-secrets.service
  -> /run/secrets/attic-upload-key
```

所以这里不要临时粘贴 token，也不要使用 admin token。直接读取 SOPS 下发的 upload key：

```bash
# 这个文件由 nixos-secrets/common/attic.yaml 里的 attic-upload-key 解密生成。
# 不要把 Attic public key、admin token 或手动临时 token 填在这里。
TOKEN=$(cat /run/secrets/attic-upload-key)

nix shell nixpkgs#attic-client -c attic login --set-default lantian \
  https://attic.zhyi.cc:4000 "$TOKEN"
```

验证配置时不要直接 `cat` 整个 config，里面可能保存 token。只看 server 和 endpoint：

```bash
grep -E '^(default-server|endpoint) = ' /root/.config/attic/config.toml
```

应看到：

```text
default-server = "lantian"
endpoint = "https://attic.zhyi.cc:4000"
```

如果 `attic login` 或 `attic push` 报权限错误，说明 `common/attic.yaml` 里的 `attic-upload-key` 不是当前 cache 可用的 upload token。生成新 token 后写回 secrets：

```bash
CONFIG=$(systemctl cat atticd.service | sed -n 's|^ExecStart=.* -f \([^ ]*\) --mode.*|\1|p' | tail -1)

set -a
. /run/secrets/attic-credentials
set +a

atticadm -f "$CONFIG" make-token \
  --sub attic-upload \
  --validity 10y \
  --pull lantian \
  --push lantian
```

把输出的整串 token 写入 `nixos-secrets/common/attic.yaml`：

```yaml
attic-upload-key: |
  <新 token>
```

然后提交 `nixos-secrets`，回主仓库执行 `nix flake update secrets`，切换 `ml-builder-cache` 让 `/run/secrets/attic-upload-key` 更新。

## 4. 推送当前系统闭包

如果只想先保证当前系统可复现，先推 `/run/current-system` 闭包：

```bash
nix shell nixpkgs#attic-client -c attic push lantian \
  $(nix-store -qR /run/current-system)
```

这个范围较小，适合快速验证。

## 5. 推送 GC roots 闭包

如果希望推送当前仍被 GC root 保留的主要内容：

```bash
nix-store -qR /nix/var/nix/gcroots \
  | xargs -r -n 200 nix shell nixpkgs#attic-client -c attic push lantian
```

这个范围比当前系统闭包大，但通常仍然比全 `/nix/store` 可控。

## 6. 全量推送 /nix/store

确认要全量推送时，使用分批方式，避免一次命令参数过长：

```bash
find /nix/store -mindepth 1 -maxdepth 1 ! -name '.*' -print0 \
  | xargs -0 -r -n 200 nix shell nixpkgs#attic-client -c attic push lantian
```

说明：

- `! -name '.*'` 会排除 `/nix/store/.links` 这类 Nix 内部目录；它不是合法 store path，传给 `attic push` 会报 `Path is too short`。
- `-n 200` 会分批推送，避免一次传入过多参数。
- `-r` 避免没有输入时仍然执行一次 `attic push`。
- 如果刚重建过 Attic cache，先重新执行第 3 节的 `attic login`，否则本机可能还在使用旧 token/session，出现 `AccessError`。
- 已存在于 Attic 的 path 会被跳过或去重。
- 重跑同一条命令不会重复占用完整空间。
- 如果中途中断，重新执行同一条命令即可继续补齐。
- 如果出现少量 `HTTP 502 Bad Gateway`，先确认反代/S3 后端是否稳定，然后重跑命令。

## 7. 观察自动上传服务

另开一个 SSH 或 tmux pane：

```bash
journalctl -u attic-watch-store.service -f
```

正常会看到类似：

```text
✅ <store-path-name> (deduplicated)
✅ <store-path-name> (4.42 KiB/s)
```

如果看到：

```text
❌ <store-path-name>: HTTP 502 Bad Gateway
```

表示这次上传失败。修好 Attic/S3 后，重新跑全量推送即可补齐。

## 8. 抽样验证

推送结束后，可以抽样确认某个 path 已在 Attic：

```bash
P=/nix/store/<hash-name>
nix path-info --store https://attic.zhyi.cc:4000/lantian "$P"
```

也可以验证当前系统闭包是否还缺路径：

```bash
STORE=https://attic.zhyi.cc:4000/lantian
MISSING=0

while IFS= read -r p; do
  if ! nix path-info --store "$STORE" "$p" >/dev/null 2>&1; then
    echo "MISSING $p"
    MISSING=$((MISSING + 1))
  fi
done < <(nix-store -qR /run/current-system)

echo "missing=$MISSING"
```

`missing=0` 表示当前系统闭包已经完整进入 Attic。

## 9. 客户端使用的缓存配置

主仓库里 Nix 客户端使用的 substituter 和 public key 在：

```text
helpers/constants/nix.nix
```

当前关键值：

```text
substituter: https://attic.zhyi.cc:4000/lantian
public key:  lantian:bb++Di9jcflg4iRdiONgxrLRTLs2SdoVjIZaG6l5lEU=
```

如果以后重建 Attic cache，public key 可能变化。变化后必须同步更新 `helpers/constants/nix.nix`，否则客户端会出现：

```text
warning: ignoring substitute ... as it's not signed by any of the keys in 'trusted-public-keys'
```

