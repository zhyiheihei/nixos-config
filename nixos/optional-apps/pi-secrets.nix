{ inputs, ... }:
{
  sops.secrets.pi-magic-context-openrouter-key = {
    sopsFile = inputs.secrets + "/pi.yaml";
    owner = "zhyi";
    group = "zhyi";
  };
}
