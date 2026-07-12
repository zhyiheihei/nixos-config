# ml-builder-cache follow-ups

Current minimal fix:

- `ml-builder-cache` uses local Attic directly as a Nix substituter:
  `http://127.0.0.1:13803/lantian`
- Other hosts still use the public Attic URL from `helpers/constants/nix.nix`:
  `https://attic.zhyi.xin:8443/lantian`

Why:

- On `ml-builder-cache`, `attic.zhyi.xin` resolves back to the machine's LTNET
  address.
- The public HTTPS `:4000` entrypoint is handled outside Attic itself.
- Attic listens locally on `LT.port.Attic` / `13803`, so the cache host can use
  that directly and avoid depending on its own public reverse-proxy path.

Future cleanup:

- Decide whether `attic.zhyi.xin:8443` should be served by this host, router
  forwarding, or another reverse proxy.
- If Nginx on this host serves `attic.zhyi.xin`, make sure the matching
  certificate export exists, for example `zerossl-zhyi.cc`.
- Replace or remove author-domain vhosts such as `hydra.lantian.pub` once the
  local `hydra.zhyi.cc` path is finalized.
