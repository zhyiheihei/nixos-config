# Home LAN IP Plan

The home LAN is `192.168.2.0/24`. Infrastructure uses static addresses below
the DHCP pool; OpenWrt allocates dynamic leases from `192.168.2.100` upward.

| Address | Host | Interface MAC | Status |
| --- | --- | --- | --- |
| `192.168.2.2` | OpenWrt router | managed on the router | active gateway |
| `192.168.2.50` | `ml-builder` | `00:0c:29:25:ae:72` | active strong builder |
| `192.168.2.51` | `ml-home-vm` | `bc:24:11:39:ef:6b` | active home services and NCPS |
| `192.168.2.52` | `colocrossing` | `bc:24:11:39:22:9b` | active Attic and home ingress |
| `192.168.2.53` | `pve-2700` | `1c:83:41:29:62:48` | retained legacy host, not a current deployment target |
| `192.168.2.54` | `pve-5700u` | `1c:83:41:40:c0:7a` | active PVE and Hydra host |
| `192.168.2.93` | QNAP NAS | managed outside this repository | active NFS and S3 storage |

Before deploying `ml-home-vm`, allow `192.168.2.51` in the QNAP NFS export
that serves `192.168.2.93:/nixos`.
