{
  config ? { },
  pkgs ? { },
  lib ? pkgs.lib,
  inputs,
  self ? null,
  hostsBase ? ../hosts,
  hostsExamBase ? ../hosts-exam,
  ...
}:
let
  compatibilityExampleHostNames = [
    "alice"
    "bwg-lax"
    "lt-dell-wyse"
    "lt-dell-wyse-thin"
    "lt-home-rdp"
    "lt-hp-omen"
    "terrahost"
    "v-ps-sea"
    "virmach-ny1g"
    "virmach-ny6g"
    "zgocloud"
  ];
  callWith =
    path: args:
    builtins.removeAttrs (lib.callPackageWith (pkgs // helpers) path args) [
      "override"
      "overrideDerivation"
    ];
  call = path: callWith path { };
  helpers = rec {
    inherit
      config
      pkgs
      lib
      inputs
      self
      hostsBase
      hostsExamBase
      ;
    inherit (inputs.nix-math.lib) math;

    constants = call ./constants.nix;
    inherit (constants)
      port
      portStr
      tags
      interfacePrefixes
      zones
      reserved
      stateVersion
      asteriskMusics
      bindfsMountOptions
      bindfsMountOptions'
      dn42
      neonetwork
      matrixWellKnown
      nix
      ;
    geo = call ./geo.nix;

    sources = call _sources/generated.nix;

    activeHosts = callWith ./fn/hosts.nix { inherit hostsBase; };
    exampleHosts = lib.getAttrs compatibilityExampleHostNames (
      callWith ./fn/hosts.nix { hostsBase = hostsExamBase; }
    );
    hosts = activeHosts // exampleHosts;
    this = hosts."${config.networking.hostName}";
    otherHosts = builtins.removeAttrs hosts [ config.networking.hostName ];

    hostsWithTag = tag: lib.filterAttrs (n: v: v.hasTag tag) hosts;
    hostsWithoutTag = tag: lib.filterAttrs (n: v: !(v.hasTag tag)) hosts;
    otherHostsWithTag = tag: builtins.removeAttrs (hostsWithTag tag) [ config.networking.hostName ];
    otherHostsWithoutTag =
      tag: builtins.removeAttrs (hostsWithoutTag tag) [ config.networking.hostName ];

    patchedNixpkgs = self.packages."${this.system}".pkgs-patched;

    cloudLanNetworking = call ./fn/cloud-lan-networking.nix;
    gui = call ./fn/gui.nix;
    inherit (call ./fn/interconnect.nix)
      interconnectIPv4For
      publicIPv4For
      interconnectIPv6For
      publicIPv6For
      ;
    ls = call ./fn/ls.nix;
    nginx = call ./fn/nginx.nix;
    sanitizeName = call ./fn/sanitize-name.nix;
    inherit (call ./fn/service-harden.nix) serviceHarden networkToolHarden;
    tagsForHost = call ./fn/tags-for-host.nix;
    translit = call ./fn/translit.nix;
    wrapNetns = call ./fn/wrap-netns.nix;
    zerotier = call ./fn/zerotier.nix;
    inherit (call ./fn/random.nix) random randomSelect;
  };
in
helpers
