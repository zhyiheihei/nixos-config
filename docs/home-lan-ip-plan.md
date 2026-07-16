# Home LAN IP Plan

The home LAN is `192.168.2.0/24`. Infrastructure uses static addresses below
the DHCP pool; OpenWrt allocates dynamic leases from `192.168.2.100` upward.

| Address | Host | Interface MAC |
| --- | --- | --- |
| `192.168.2.2` | OpenWrt router | managed on the router |
| `192.168.2.50` | `ml-builder` | `00:0c:29:25:ae:72` |
| `192.168.2.51` | `ml-home-vm` | `bc:24:11:39:ef:6b` |
| `192.168.2.52` | `colocrossing` | `bc:24:11:39:22:9b` |
| `192.168.2.53` | `pve-2700` | `1c:83:41:29:62:48` |
| `192.168.2.54` | `pve-5700u` | `1c:83:41:40:c0:7a` |
| `192.168.2.93` | QNAP NAS | managed outside this repository |

Before deploying `ml-home-vm`, allow `192.168.2.51` in the QNAP NFS export
that serves `192.168.2.93:/nixos`.
