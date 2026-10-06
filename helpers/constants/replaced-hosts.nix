_: {
  replacedHosts = {
    # Old host names that have been replaced by a new host.
    # Used by DNS record generation (dns/common/host-recs.nix), acme certificate
    # issuance (nixos/optional-apps/acme/base-domains.nix) and the nginx redirect
    # vhosts (nixos/common-apps/nginx/vhost-replaced-hosts.nix).
    # keep-sorted start
    "50kvm" = "volcengine";
    "v-ps-hkg" = "volcengine";
    "v-ps-sjc" = "hostdare";
    gigsgigscloud = "volcengine";
    hetzner-de = "greencloud";
    hostdare = "hostdare";
    linkin = "volcengine";
    oneprovider = "greencloud";
    soyoustart = "greencloud";
    virmach-ny1g = "greencloud";
    virmach-ny3ip = "greencloud";
    virmach-ny6g = "greencloud";
    virtono = "google";
    # keep-sorted end
  };
}
