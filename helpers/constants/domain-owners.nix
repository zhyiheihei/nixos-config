_: {
  # Domains whose serving host differs from the host that declares the vhost.
  # `hosts.nix` uses this to route `/etc/hosts` entries to the real owner over
  # LTNET instead of self-mapping a shared/leftover vhost name.
  #
  # The author's original topology syncs the static apex site to every server,
  # so self-mapping is correct there. This replica serves `zhyi.xin` from Halo
  # on cnvm, so every other host must resolve the apex to cnvm.
  "zhyi.xin" = "cnvm";
}
