{
  lib,
  LT,
  ...
}:
let
  domains = [
    "zhyi.xin"
  ];

  emailConfigFor = domain: {
    inherit domain;
    imap = {
      server = "witcher.mxrouting.net";
      port = 993;
      starttls = false;
    };
    smtp = {
      server = "witcher.mxrouting.net";
      port = 465;
      starttls = false;
    };
  };

  minifyXML =
    s:
    lib.concatMapStrings (
      v:
      let
        strip = s: lib.removePrefix " " (lib.removeSuffix " " s);
        process = s: if strip s == s then s else process (strip s);
      in
      process v
    ) (lib.splitString "\n" s);

  autoconfigTemplate =
    cfg:
    minifyXML ''
      <?xml version="1.0" encoding="UTF-8"?>
      <clientConfig version="1.1">
        <emailProvider id="${cfg.domain}">
            <domain>${cfg.domain}</domain>

            <displayName>%EMAILADDRESS%</displayName>
            <displayShortName>%EMAILLOCALPART%</displayShortName>

            <incomingServer type="imap">
            <hostname>${cfg.imap.server}</hostname>
            <port>${builtins.toString cfg.imap.port}</port>
            <socketType>${if cfg.imap.starttls then "STARTTLS" else "SSL"}</socketType>
            <authentication>password-cleartext</authentication>
            <username>%EMAILADDRESS%</username>
          </incomingServer>

            <outgoingServer type="smtp">
            <hostname>${cfg.smtp.server}</hostname>
            <port>${builtins.toString cfg.smtp.port}</port>
            <socketType>${if cfg.smtp.starttls then "STARTTLS" else "SSL"}</socketType>
            <authentication>password-cleartext</authentication>
            <username>%EMAILADDRESS%</username>
            </outgoingServer>
        </emailProvider>
      </clientConfig>
    '';

  autodiscoverJsonTemplate =
    cfg:
    builtins.toJSON {
      Protocol = "AutodiscoverV1";
      Url = "https://autoconfig.${cfg.domain}/autodiscover/autodiscover.xml";
    };
in
lib.mkIf (LT.this.hasTag LT.tags.public-facing) {
  lantian.nginxVhosts = builtins.listToAttrs (
    builtins.map (
      domain:
      lib.nameValuePair "autoconfig.${domain}" {
        locations = {
          "/mail/config-v1.1.xml" = {
            return = "200 '${autoconfigTemplate (emailConfigFor domain)}'";
            extraConfig = ''
              add_header 'Content-Type' 'text/xml; charset=utf-8';
            '';
          };
          "/autodiscover/autodiscover.json" = {
            return = "200 '${autodiscoverJsonTemplate (emailConfigFor domain)}'";
            extraConfig = ''
              default_type application/json;
            '';
          };
        };
        sslCertificate = "lets-encrypt-${domain}";
        noIndex.enable = true;
      }
    ) domains
  );
}
