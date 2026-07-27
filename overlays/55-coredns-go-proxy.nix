_: _final: prev: {
  nur-xddxdd = prev.nur-xddxdd // {
    lantianCustomized = prev.nur-xddxdd.lantianCustomized // {
      coredns = prev.nur-xddxdd.lantianCustomized.coredns.overrideAttrs (old: {
        env = (old.env or { }) // {
          # The default proxy.golang.org endpoint is unreachable from the
          # mainland builder.  This also applies to buildGoModule's fixed-output
          # go-modules derivation, where CoreDNS fetches its extra plugins.
          GOPROXY = "https://goproxy.cn,direct";
        };
      });
    };
  };
}
