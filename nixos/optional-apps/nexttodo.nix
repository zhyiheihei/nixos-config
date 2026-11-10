{
  LT,
  config,
  pkgs,
  ...
}:
{
  virtualisation.oci-containers.containers.nexttodo = {
    environment.RUST_LOG = "info";
    image = "ghcr.io/juniexd/nexttodo:latest";
    labels."io.containers.autoupdate" = "registry";
    ports = [ "127.0.0.1:${LT.portStr.NextTodo}:8080" ];
    volumes = [ "/var/lib/nexttodo/data:/data" ];
  };

  systemd.tmpfiles.settings.nexttodo = {
    "/var/lib/nexttodo/data"."d" = {
      mode = "0700";
      user = "65534";
      group = "65534";
    };
  };

  systemd.services.nexttodo-setup = {
    description = "Create the NextTodo administrator from the unified credentials";
    after = [
      "podman-nexttodo.service"
      "sops-install-secrets.service"
    ];
    wants = [ "podman-nexttodo.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      Restart = "on-failure";
      RestartSec = "10s";
      TimeoutStartSec = "10min";
    };
    path = [
      pkgs.curl
      pkgs.jq
      pkgs.podman
    ];
    script = ''
      admin_password=$(<${config.sops.secrets.default-pw.path})
      payload=$(jq -cn --arg u zhyi --arg p "$admin_password" --arg d server-setup \
        '{username:$u,password:$p,device:$d}')

      for i in $(seq 1 60); do
        curl -sf -m 3 http://127.0.0.1:${LT.portStr.NextTodo}/ >/dev/null && break
        sleep 2
      done

      if ! curl -sf -m 5 -X POST http://127.0.0.1:${LT.portStr.NextTodo}/api/v1/auth/login \
        -H 'Content-Type: application/json' -d "$payload" >/dev/null; then
        printf '%s\n%s\n' "$admin_password" "$admin_password" \
          | podman exec -i nexttodo /nexttodo-server create-admin zhyi || true
        curl -sf -m 5 -X POST http://127.0.0.1:${LT.portStr.NextTodo}/api/v1/auth/login \
          -H 'Content-Type: application/json' -d "$payload" >/dev/null || {
          echo "NextTodo administrator zhyi cannot log in with the default password" >&2
          exit 1
        }
      fi
    '';
  };

  lantian.nginxVhosts."nexttodo.zhyi.xin" = {
    locations."/" = {
      proxyPass = "http://127.0.0.1:${LT.portStr.NextTodo}";
      proxyWebsockets = true;
      proxyNoTimeout = true;
    };

    sslCertificate = "lets-encrypt-zhyi.xin";
    noIndex.enable = true;
  };
}
