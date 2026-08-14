{ lib, ... }:
let
  formatArg =
    let
      escapeArg = arg: "'${lib.replaceStrings [ "'" ] [ "'\\''" ] (toString arg)}'";
    in
    s:
    if builtins.isString s then
      escapeArg s
    else if builtins.isAttrs s then
      builtins.toJSON s
    else
      builtins.toString s;
  formatName = name: reverse: if reverse then "REV(${formatArg name})" else (formatArg name);

  record =
    recordType: args: params:
    let
      configString = builtins.concatStringsSep ", " (
        [ (formatName args.name args.reverse) ]
        ++ (builtins.map formatArg params)
        ++ (lib.optionals (args ? meta) (builtins.map formatArg [ args.meta ]))
        ++ (lib.optional (args.ttl != null) "TTL(${formatArg (builtins.toString args.ttl)})")
        ++ (lib.optional (args.cloudflare != null && args.cloudflare) "CF_PROXY_ON")
        ++ (lib.optional (args.cloudflare != null && !args.cloudflare) "CF_PROXY_OFF")
      );
    in
    [ "${recordType}(${configString})" ];
in
{
  recordHandlers = rec {
    A = args: record "A" args [ args.address ];
    AAAA = args: record "AAAA" args [ args.address ];
    ALIAS = args: record "ALIAS" args [ args.target ];
    AUTO = args: if lib.hasInfix ":" args.address then AAAA args else A args;
    CAA =
      args:
      record "CAA" args [
        args.tag
        args.value
      ];
    CNAME = args: record "CNAME" args [ args.target ];
    DS =
      args:
      record "DS" args [
        args.keytag
        args.algorithm
        args.digesttype
        args.digest
      ];
    HTTPS =
      args:
      record "HTTPS" args [
        args.priority
        args.target
        args.modifiers
      ];
    IGNORE = args: record "IGNORE" args [ args.type ];
    MX =
      args:
      record "MX" args [
        args.priority
        args.target
      ];
    NO_PURGE = _: [ "NO_PURGE" ];
    NAMESERVER = args: record "NAMESERVER" args [ ];
    NAPTR =
      args:
      record "NAPTR" args [
        args.order
        args.preference
        args.terminalFlag
        args.service
        # Workaround DNSControl bug
        (lib.replaceStrings [ "\\" ] [ "\\\\\\\\" ] args.regexp)
        args.target
      ];
    NS = args: record "NS" args [ args.target ];
    PTR = args: record "PTR" args [ args.target ];
    SOA =
      args:
      record "SOA" args [
        args.nameserver
        args.email
        args.refresh
        args.retry
        args.expire
        args.minimum
      ];
    SRV =
      args:
      record "SRV" args [
        args.priority
        args.weight
        args.port
        args.target
      ];
    SSHFP =
      args:
      record "SSHFP" args [
        args.algorithm
        args.type
        args.value
      ];
    SVCB =
      args:
      record "SVCB" args [
        args.priority
        args.target
        args.modifiers
      ];
    TLSA =
      args:
      record "TLSA" args [
        args.usage
        args.selector
        args.type
        args.certificate
      ];
    TXT = args: record "TXT" args [ args.contents ];
  };
}
