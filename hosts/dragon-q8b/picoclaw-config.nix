{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
{
  sops.secrets."uni-api-picoclaw-api-key" = {
    sopsFile = inputs.secrets + "/uni-api/keys.yaml";
    owner = "zhyi";
    group = "zhyi";
  };

  # / 为 tmpfs，picoclaw 的 config.json 无法跨重启存活；开机用 picoclaw 专用
  # key 拼装种子配置（缺文件或缺目标模型即重写， healed 后的运行期改动保留）。
  systemd.services.picoclaw-config-seed = {
    wantedBy = [ "multi-user.target" ];
    before = [ "picoclaw.service" ];
    serviceConfig = {
      Type = "oneshot";
      UMask = "0077";
    };
    script = ''
      install -d -m700 -o zhyi -g zhyi /home/zhyi/.picoclaw
      if [ ! -f /home/zhyi/.picoclaw/config.json ] || ! grep -q gpt-5.6-luna /home/zhyi/.picoclaw/config.json; then
        ${lib.getExe pkgs.jq} -n --arg key "$(cat ${
          config.sops.secrets."uni-api-picoclaw-api-key".path
        })" '{
          version: 3,
          agents: {defaults: {model_name: "gpt-5.6-luna", workspace: "~/.picoclaw/workspace", restrict_to_workspace: true}},
          model_list: [{
            model_name: "gpt-5.6-luna",
            model: "openai/gpt-5.6-luna",
            api_keys: [$key],
            api_base: "https://ai-api.zhyi.xin/v1"
          }]
        }' > /home/zhyi/.picoclaw/config.json
        chown zhyi:zhyi /home/zhyi/.picoclaw/config.json
        chmod 600 /home/zhyi/.picoclaw/config.json
      fi
    '';
  };
}
