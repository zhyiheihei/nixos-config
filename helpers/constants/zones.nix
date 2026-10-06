{ lib, ... }:
let
  zones = {
    DN42 = [
      "dn42"
      "10.in-addr.arpa"
      "20.172.in-addr.arpa"
      "21.172.in-addr.arpa"
      "22.172.in-addr.arpa"
      "23.172.in-addr.arpa"
      "31.172.in-addr.arpa"
      "d.f.ip6.arpa"
    ];
    OpenNIC = [
      "bbs"
      "chan"
      "cyb"
      "dns.opennic.glue"
      "dyn"
      "epic"
      "geek"
      "gopher"
      "indy"
      "libre"
      "null"
      "o"
      "opennic.glue"
      "oss"
      "oz"
      "parody"
      "pirate"
    ];
    Emercoin = [
      "bazar"
      "coin"
      "emc"
      "lib"
    ];
    YggdrasilAlfis = [
      "anon"
      "btn"
      "conf"
      "index"
      "merch"
      "mirror"
      "mob"
      "screen"
      "srv"
      "ygg"
    ];
    CRXN = [ "crxn" ];
    Meshname = [
      "meshname"
      "meship"
    ];
    Ltnet = [
      "18.198.in-addr.arpa"
      "19.198.in-addr.arpa"
      "d.a.7.6.c.d.9.f.c.b.d.f.ip6.arpa"
      "zhyi.dn42"
    ];
    Others = [
      # Custom overrides
      "database.azure.com"
    ];
  };
in
{
  zones = zones // {
    all = lib.flatten (builtins.attrValues zones);
  };
}
