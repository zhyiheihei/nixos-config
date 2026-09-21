{
  pkgs,
  lib,
  inputs,
  ...
}:
let
  sources = pkgs.callPackage ../../helpers/_sources/generated.nix { };
  dnscontrol = pkgs.buildGo127Module rec {
    inherit (sources.dnscontrol-xddxdd) pname version src;
    # 2026-09-21：nixpkgs 前移后 go 工具链变化导致 go-modules FOD 确定性产出
    # 与旧 vendorHash 失配（exam 同 hash 在我们 nixpkgs 锁下同样无法构建），
    # 按 ml-builder 实测产出更新；上游/exam 后续跟进后可回退对齐。
    vendorHash = "sha256-MhF/ZUPj3slDD9Pn3j4Gy0WT3iGHlF7o7sMjo6DS+y8=";

    ldflags = [
      "-s"
      "-w"
    ];

    preCheck = ''
      # requires network
      rm pkg/spflib/flatten_test.go pkg/spflib/parse_test.go
    '';

    meta.mainProgram = "dnscontrol";
  };
in
''
  set -euxo pipefail

  CURR_DIR="$(pwd)"

  TEMP_DIR="$(mktemp -d /tmp/dns.XXXXXXXX)"
  nix build .#dnscontrol-config -o "$TEMP_DIR/dnsconfig.js"

  if [ -d "$CURR_DIR/zones" ]; then
    cp -r "$CURR_DIR/zones" "$TEMP_DIR/zones"
  fi

  ${lib.getExe pkgs.ssh-to-age} -private-key -i "$HOME/.ssh/id_ed25519" \
    > "$TEMP_DIR/age_key"
  SOPS_AGE_KEY_FILE="$TEMP_DIR/age_key" \
    ${lib.getExe pkgs.sops} decrypt \
    --extract '["dnscontrol"]' \
    --output "$TEMP_DIR/creds.json" \
    "${inputs.secrets}/dnscontrol.yaml"
  mkdir -p "$TEMP_DIR/zones"

  cd "$TEMP_DIR"
  ${lib.getExe dnscontrol} $* && RET=0 || RET=$?
  rm -rf "$CURR_DIR/zones"
  mv "$TEMP_DIR/zones" "$CURR_DIR/zones"

  cd "$CURR_DIR"
  rm -rf "$TEMP_DIR"
  exit $RET
''
