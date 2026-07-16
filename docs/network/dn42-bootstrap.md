# DN42 bootstrap

## Registered identity

The initial registration is tracked in the DN42 Registry pull request created
from the `register-zhyi` branch.

- Maintainer: `ZHYI-MNT`
- Contact: `ZHYI-DN42`
- ASN: `AS4242423712`
- IPv4 allocation: `172.20.46.224/27`
- IPv6 allocation: `fdd8:1938:4e88::/48`
- Domain: `zhyi.dn42`

The Registry pull request has been merged. These resources may only be
announced by the configured ZHYI DN42 routers.

## Active routers

`jpvm` is the current external DN42 ingress. Its WireGuard and MP-BGP session
to `sg1.g-load.eu` is defined by the encrypted hidden module and carries both
IPv4 and IPv6 routes.

`colocrossing` is the home-side DN42 router and authoritative DNS server.

- IPv4: `172.20.46.225`
- IPv6: `fdd8:1938:4e88:18::1`
- Nameserver: `ns1.zhyi.dn42`

The two routers exchange LTNET routes through the same WireGuard and BIRD
layout as the upstream configuration. A host participates in this live mesh
only when it has both the `server` tag and a ZeroTier node ID. This keeps
retained upstream host examples out of the active routing table without
changing their reference configurations.

## Activation order

1. Store the WireGuard private key in the existing per-host SOPS secret.
2. Add peer parameters to the target router's encrypted hidden module.
3. Verify the WireGuard handshake and both BIRD BGP sessions.
4. Verify that the `/27` and `/48` are exported with valid ROAs.
5. Configure the authoritative `zhyi.dn42` zone and reverse DNS.
6. Obtain the Kioubit CA token and encrypt it as
   `dn42-certificate-token.yaml` before enabling the DN42 TLS vhosts.

## Deferred resources

The author uses a second test ASN and a DN42 telephony allocation. They are not
part of the initial registration. Asterisk and `tel.dn42` therefore retain the
author example values and must not be deployed until equivalent ZHYI resources
have been registered.
