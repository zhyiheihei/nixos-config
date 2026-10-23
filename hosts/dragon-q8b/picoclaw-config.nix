{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
{
  sops.secrets."ai-api-key" = {
    sopsFile = inputs.secrets + "/ai-api.yaml";
    owner = "zhyi";
    group = "zhyi";
  };

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
        ${lib.getExe pkgs.jq} -n --arg key "$(cat ${config.sops.secrets."ai-api-key".path})" '{
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
