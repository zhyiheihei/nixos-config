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

Do not announce these resources before the Registry pull request is merged.

## First router

`colocrossing` is the first DN42 router and authoritative DNS server.

- IPv4: `172.20.46.225`
- IPv6: `fdd8:1938:4e88:18::1`
- Nameserver: `ns1.zhyi.dn42`

During the single-node stage, public DN42 service records point to this node.
The author's multi-node DNS and anycast layout can be restored as more DN42
routers are added.

## Activation order

1. Wait for the Registry pull request to be merged.
2. Find a nearby peer that supports WireGuard and dual-stack MP-BGP.
3. Store the WireGuard private key in the existing per-host SOPS secret.
4. Add the peer parameters to one of the colocrossing hidden modules.
5. Verify the WireGuard handshake and BIRD BGP session.
6. Verify that the `/27` and `/48` are exported with valid ROAs.
7. Configure the authoritative `zhyi.dn42` zone and reverse DNS.
8. Obtain the Kioubit CA token and encrypt it as
   `dn42-certificate-token.yaml` before enabling the DN42 TLS vhosts.

## Deferred resources

The author uses a second test ASN and a DN42 telephony allocation. They are not
part of the initial registration. Asterisk and `tel.dn42` therefore retain the
author example values and must not be deployed until equivalent ZHYI resources
have been registered.
