{
  lib,
  LT,
  config,
  self,
  pkgs,
  ...
}:
let
  addConfLantianPub =
    args:
    let
      enableCompression = ''
        gzip on;
        brotli on;
        zstd on;
      '';
    in
    lib.recursiveUpdate args {
      locations = {
        "/" = {
          index = "index.html index.htm";
        };
        "/assets/".extraConfig = ''
          expires 31536000;
        '';
        "/usr/".extraConfig = ''
          expires 31536000;
          add_header Vary "Accept";
          add_header Cache-Control "public, no-transform";
        '';
        "= /favicon.ico".extraConfig = ''
          expires 31536000;
        '';
        "/feed".tryFiles = "$uri /feed.xml /atom.xml =404";

        # Plausible Analytics
        "= /api/event" = {
          proxyPass = "http://198.18.${
            builtins.toString LT.hosts."greencloud".index
          }.138:${LT.portStr.Plausible}";
          extraConfig = enableCompression;
        };

        # Waline
        "= /api/comment" = {
          proxyPass = "http://${LT.hosts."greencloud".ltnet.IPv4}:${LT.portStr.Waline}";
          extraConfig = ''
            proxy_set_header REMOTE-HOST $remote_addr;
            ${enableCompression}
          '';
        };

        # Matrix Federation
        "= /.well-known/matrix/server" = {
          allowCORS = true;
          return = "200 '${LT.constants.matrixWellKnown.server}'";
          extraConfig = ''
            default_type application/json;
            ${enableCompression}
          '';
        };
        "= /.well-known/matrix/client" = {
          allowCORS = true;
          return = "200 '${LT.constants.matrixWellKnown.client}'";
          extraConfig = ''
            default_type application/json;
            ${enableCompression}
          '';
        };
        "= /.well-known/webfinger".return =
          "302 'https://mastodon.social/.well-known/webfinger?resource=acct:molishanguang@mastodon.social'";

        # ATproto
        "= /.well-known/atproto-did".return = "200 'did:plc:bojfoltwtzihrpbrkpkj3ijm'";

        # DN42
        "= /dn42-geofeed.csv" = {
          root = builtins.toString self.packages.${pkgs.stdenv.hostPlatform.system}.dn42-geofeed;
        };
      };

      root = "/nix/sync-servers/www/zhyi.xin";

      disableLiveCompression = true;

      extraConfig = ''
        error_page 404 /404.html;
      ''
      + (args.extraConfig or "");
    };
in
{
  lantian.nginxVhosts = {
    "zhyi.xin" = addConfLantianPub {
      serverAliases = [ "${config.networking.hostName}.zhyi.xin" ];
      sslCertificate = "zerossl-zhyi.xin";
    };
    "zhyi.dn42" = addConfLantianPub {
      listenHTTP.enable = true;
      serverAliases = [ "${config.networking.hostName}.zhyi.dn42" ];
      sslCertificate = "dn42-zhyi.dn42";
    };
    # Don't use globalRedirect, it adds http:// prefix
    "www.zhyi.xin" = {
      locations."/".return = "307 https://zhyi.xin$request_uri";
      enableCommonLocationOptions = false;
      sslCertificate = "zerossl-zhyi.xin";
    };
    # lab.xuyh0120.win 在上游重定向到 lab.lantian.pub（跨域到正牌 lab 站）；
    # 域名统一并入 zhyi.xin 后跨域重定向退化为自跳（G1 死链），而真实的
    # lab 站由 nginx-lab 模块的 lab.zhyi.xin vhost 承担，故删去此重定向块
    # （2026-09-04，homepage 检查 G1）。
  }
  // lib.optionalAttrs (LT.this.hasTag LT.tags.public-facing) {
    "gopher.zhyi.xin" = {
      listenHTTP.enable = true;
      listenPlainSocket = {
        enable = true;
        socket = "/run/nginx/gopher.sock";
        proxyProtocol = true;
        default = true;
      };

      root = "/nix/sync-servers/www/zhyi.xin";
      serverAliases = [
        "gopher.zhyi.dn42"
      ];

      locations."/" = {
        index = "gophermap";
        extraConfig = ''
          sub_filter "{{server_addr}}\t{{server_port}}" "$gopher_addr\t70";
          sub_filter_once off;
          sub_filter_types '*';
        '';
      };

      enableCommonLocationOptions = false;
      noIndex.enable = true;

      sslCertificate = "zerossl-zhyi.xin";

      extraConfig = ''
        error_page 404 /404.gopher;
      '';
    };

    "gemini.zhyi.xin" = {
      listenHTTP.enable = true;
      listenGeminiSocket = {
        enable = true;
        socket = "/run/nginx/gemini.sock";
        proxyProtocol = true;
        default = true;
      };

      root = "/nix/sync-servers/www/zhyi.xin";
      serverAliases = [
        "gemini.zhyi.dn42"
      ];

      locations."/".index = "index.gmi";

      enableCommonLocationOptions = false;
      noIndex.enable = true;

      sslCertificate = "zerossl-zhyi.xin";

      extraConfig = ''
        error_page 404 /404.gopher;
      '';
    };
  };
}
