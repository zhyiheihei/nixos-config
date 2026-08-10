{
  config,
  inputs,
  lib,
  LT,
  pkgs,
  ...
}:
let
  dataDir = "/var/lib/sublinkpro";
  dbDir = "${dataDir}/db";
  templateDir = "${dataDir}/template";
  logDir = "${dataDir}/logs";

  mkSubscriptionLocation = template: {
    extraConfig = ''
      include ${config.sops.templates."sublinkpro-token.nginx".path};
      default_type text/yaml;
      add_header Content-Disposition 'attachment; filename=mihomo.yaml';
      alias ${config.sops.templates.${template}.path};
    '';
  };

  sublinkClashTemplate = pkgs.writeText "sublinkpro-clash.yaml" (builtins.readFile ./clash.yaml);
in
{
  sops.secrets = {
    v2ray-key = {
      sopsFile = inputs.secrets + "/common/v2ray.yaml";
    };
  };

  sops.templates."sublinkpro-env" = {
    owner = "root";
    group = "root";
    mode = "0400";
    content = ''
      SUBLINK_ADMIN_PASSWORD=${config.sops.placeholder.default-pw}
      SUBLINK_SHARE_TOKEN=${config.sops.placeholder.default-pw}
      SUBLINK_V2RAY_UUID=${config.sops.placeholder.v2ray-key}
    '';
  };

  # Keep the legacy static subscriptions working while SublinkPro takes over
  # the panel and the unified /c/ subscription path.
  sops.templates."sublinkpro-mihomo.yaml" = {
    owner = "nginx";
    group = "nginx";
    mode = "0440";
    content = ''
      mixed-port: 7890
      allow-lan: true
      mode: rule
      log-level: info
      ipv6: true

      proxies:
        - name: jpvm
          type: vless
          server: jpvm.zhyi.cc
          port: 443
          uuid: "${config.sops.placeholder.v2ray-key}"
          network: xhttp
          tls: true
          udp: true
          servername: jpvm.zhyi.cc
          client-fingerprint: chrome
          encryption: ""
          xhttp-opts:
            path: /ray
            host: jpvm.zhyi.cc
            mode: stream-up
        - name: usvm
          type: vless
          server: usvm.zhyi.cc
          port: 443
          uuid: "${config.sops.placeholder.v2ray-key}"
          network: xhttp
          tls: true
          udp: true
          servername: usvm.zhyi.cc
          client-fingerprint: chrome
          encryption: ""
          xhttp-opts:
            path: /ray
            host: usvm.zhyi.cc
            mode: stream-up
        - name: colocrossing
          type: vless
          server: colocrossing.zhyi.cc
          port: 443
          uuid: "${config.sops.placeholder.v2ray-key}"
          network: xhttp
          tls: true
          udp: true
          servername: colocrossing.zhyi.cc
          client-fingerprint: chrome
          encryption: ""
          xhttp-opts:
            path: /ray
            host: colocrossing.zhyi.cc
            mode: stream-up

      proxy-groups:
        - name: PROXY
          type: select
          proxies:
            - jpvm
            - usvm
            - colocrossing
            - DIRECT

      rules:
        - DOMAIN-SUFFIX,zhyi.cc,DIRECT
        - IP-CIDR,198.18.0.0/15,DIRECT,no-resolve
        - IP-CIDR6,fdd8:1938:4e88::/48,DIRECT,no-resolve
        - IP-CIDR,127.0.0.0/8,DIRECT,no-resolve
        - IP-CIDR,10.0.0.0/8,DIRECT,no-resolve
        - IP-CIDR,172.16.0.0/12,DIRECT,no-resolve
        - IP-CIDR,192.168.0.0/16,DIRECT,no-resolve
        - IP-CIDR,100.64.0.0/10,DIRECT,no-resolve
        - IP-CIDR6,fc00::/7,DIRECT,no-resolve
        - IP-CIDR6,fe80::/10,DIRECT,no-resolve
        - GEOIP,CN,DIRECT,no-resolve
        - MATCH,PROXY
    '';
  };

  sops.templates."sublinkpro-jpvm.yaml" = {
    owner = "nginx";
    group = "nginx";
    mode = "0440";
    content = ''
      mixed-port: 7890
      allow-lan: true
      mode: rule
      log-level: info
      ipv6: true

      proxies:
        - name: jpvm
          type: vless
          server: jpvm.zhyi.cc
          port: 443
          uuid: "${config.sops.placeholder.v2ray-key}"
          network: xhttp
          tls: true
          udp: true
          servername: jpvm.zhyi.cc
          client-fingerprint: chrome
          encryption: ""
          xhttp-opts:
            path: /ray
            host: jpvm.zhyi.cc
            mode: stream-up

      proxy-groups:
        - name: PROXY
          type: select
          proxies:
            - jpvm
            - DIRECT

      rules:
        - DOMAIN-SUFFIX,zhyi.cc,DIRECT
        - IP-CIDR,198.18.0.0/15,DIRECT,no-resolve
        - IP-CIDR6,fdd8:1938:4e88::/48,DIRECT,no-resolve
        - GEOIP,CN,DIRECT,no-resolve
        - MATCH,PROXY
    '';
  };

  sops.templates."sublinkpro-token.nginx" = {
    owner = "nginx";
    group = "nginx";
    mode = "0440";
    content = ''
      if ($arg_token != "${config.sops.placeholder.v2ray-key}") {
        return 404;
      }
    '';
  };

  systemd.tmpfiles.settings.sublinkpro = {
    "${dataDir}".d = {
      mode = "0755";
      user = "root";
      group = "root";
    };
    "${dbDir}".d = {
      mode = "0755";
      user = "root";
      group = "root";
    };
    "${templateDir}".d = {
      mode = "0755";
      user = "root";
      group = "root";
    };
    "${logDir}".d = {
      mode = "0755";
      user = "root";
      group = "root";
    };
  };

  virtualisation.oci-containers.containers.sublinkpro = {
    image = "docker.io/zerodeng/sublink-pro:latest";
    labels."io.containers.autoupdate" = "registry";
    ports = [ "127.0.0.1:${LT.portStr.SublinkPro}:8000" ];
    volumes = [
      "${dbDir}:/app/db"
      "${templateDir}:/app/template"
      "${logDir}:/app/logs"
    ];
    environment = {
      SUBLINK_PORT = "8000";
      SUBLINK_DB_PATH = "/app/db";
      SUBLINK_LOG_PATH = "/app/logs";
      SUBLINK_LOG_LEVEL = "info";
      # The admin UI is behind the repo OAuth proxy, so the built-in captcha
      # would only add friction; login is still protected by the OAuth layer.
      SUBLINK_CAPTCHA_MODE = "1";
      SUBLINK_EXPIRE_DAYS = "3650";
      TZ = config.time.timeZone;
    };
    environmentFiles = [ config.sops.templates.sublinkpro-env.path ];
  };

  systemd.services.podman-sublinkpro.preStart = lib.mkBefore ''
    if [ ! -e ${templateDir}/clash.yaml ]; then
      ${pkgs.coreutils}/bin/install -Dm0644 ${sublinkClashTemplate} ${templateDir}/clash.yaml
    fi
  '';

  systemd.services.sublinkpro-seed = {
    description = "Seed SublinkPro overseas Xray nodes and unified subscription";
    after = [ "podman-sublinkpro.service" "sops-install-secrets.service" ];
    requires = [ "podman-sublinkpro.service" ];
    wantedBy = [ "multi-user.target" ];
    path = with pkgs; [ curl jq coreutils ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      EnvironmentFile = [ config.sops.templates.sublinkpro-env.path ];
    };
    script = ''
      set -eu
      api=http://127.0.0.1:${LT.portStr.SublinkPro}
      sub_config='{"clash":"./template/clash.yaml","surge":"./template/surge.conf"}'
      # The official /c/ endpoint lowercases the token before lookup, so the
      # share token derived from default-pw must be stored in lowercase.
      share_token=$(printf '%s' "$SUBLINK_SHARE_TOKEN" | tr 'A-Z' 'a-z')
      share_token_enc=$(printf '%s' "$share_token" | ${pkgs.jq}/bin/jq -sRr @uri)

      ready=false
      for _ in $(seq 1 90); do
        if ${pkgs.curl}/bin/curl -fsS "$api/api/v1/version" >/dev/null 2>&1; then
          ready=true
          break
        fi
        sleep 2
      done
      if [ "$ready" != true ]; then
        echo "SublinkPro API did not become ready" >&2
        exit 1
      fi

      login=$(${pkgs.curl}/bin/curl -fsS -X POST "$api/api/v1/auth/login" \
        -d "username=admin" \
        --data-urlencode "password=$SUBLINK_ADMIN_PASSWORD")
      token=$(printf '%s' "$login" | ${pkgs.jq}/bin/jq -r '.data.accessToken // empty')
      if [ -z "$token" ]; then
        echo "SublinkPro login failed" >&2
        exit 1
      fi

      curl_auth() {
        ${pkgs.curl}/bin/curl -fsS -H "Authorization: Bearer $token" "$@"
      }

      for node in jpvm usvm colocrossing; do
        case "$node" in
          jpvm) server=jpvm.zhyi.cc ;;
          usvm) server=usvm.zhyi.cc ;;
          colocrossing) server=colocrossing.zhyi.cc ;;
        esac
        link="vless://$SUBLINK_V2RAY_UUID@$server:443?encryption=none&security=tls&sni=$server&fp=chrome&type=xhttp&path=/ray&host=$server&mode=stream-up#$node"
        curl_auth -X POST "$api/api/v1/nodes/add" \
          --data-urlencode "link=$link" \
          --data-urlencode "name=$node" \
          --data-urlencode "group=overseas" || true
      done

      ids=$(curl_auth "$api/api/v1/nodes/get" \
        | ${pkgs.jq}/bin/jq -r '[.data[] | select(.LinkName=="jpvm" or .LinkName=="usvm" or .LinkName=="colocrossing") | .ID] | join(",")')
      if [ -z "$ids" ]; then
        echo "No overseas Xray nodes found after seeding" >&2
        exit 1
      fi

      sub_id=$(curl_auth "$api/api/v1/subcription/get" \
        | ${pkgs.jq}/bin/jq -r '.data[] | select(.Name=="统一订阅") | .ID' | head -1)
      if [ -z "$sub_id" ]; then
        curl_auth -X POST "$api/api/v1/subcription/add" \
          --data-urlencode "name=统一订阅" \
          --data-urlencode "nodeIds=$ids" \
          --data-urlencode "config=$sub_config" \
          --data-urlencode "UpdateInterval=24" || true
        sub_id=$(curl_auth "$api/api/v1/subcription/get" \
          | ${pkgs.jq}/bin/jq -r '.data[] | select(.Name=="统一订阅") | .ID' | head -1)
      fi
      if [ -z "$sub_id" ]; then
        echo "Failed to create unified subscription" >&2
        exit 1
      fi

      share_id=$(curl_auth "$api/api/v1/shares/get?subId=$sub_id" \
        | ${pkgs.jq}/bin/jq -r --arg t "$share_token" '.data[] | select(.token==$t) | .id' | head -1)
      if [ -z "$share_id" ]; then
        curl_auth -X POST "$api/api/v1/shares/add" \
          -H "Content-Type: application/json" \
          -d "{\"subscription_id\":$sub_id,\"name\":\"统一订阅\",\"token\":\"$share_token\",\"expire_type\":0}" || true
      fi

      ${pkgs.coreutils}/bin/install -d -m 0755 ${dataDir}
      {
        echo "统一订阅 (Clash/Mihomo): https://sub.zhyi.xin/c/?token=$share_token_enc&client=clash"
        echo "统一订阅 (V2Ray): https://sub.zhyi.xin/c/?token=$share_token_enc&client=v2ray"
        echo "管理页面: https://sub.zhyi.xin/"
      } > ${dataDir}/unified-subscription.txt
    '';
  };

  lantian.nginxVhosts."sub.zhyi.xin" = {
    locations = {
      "/" = {
        enableOAuth = true;
        proxyPass = "http://127.0.0.1:${LT.portStr.SublinkPro}";
        proxyWebsockets = true;
      };
      "/c/" = {
        proxyPass = "http://127.0.0.1:${LT.portStr.SublinkPro}";
        proxyWebsockets = true;
      };
      "= /mihomo.yaml" = mkSubscriptionLocation "sublinkpro-mihomo.yaml";
      "= /jpvm.yaml" = mkSubscriptionLocation "sublinkpro-jpvm.yaml";
    };
    sslCertificate = "lets-encrypt-zhyi.xin";
    noIndex.enable = true;
  };
}
