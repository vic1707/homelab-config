Create CT

---
Hostname: fedex
No nesting, no privileged
---
template: alpine
---
disk pool `VMs_LXCs`
disk size 1Gb
---
---
Swap 0
Memory: 128Mb
---
Name: `eth0`
MAC: `56:7D:19:ED:3E:40`
Bridge: `vmbr0` (default proxmox)
IPv4: DHCP
IPv6: Nothing

## Options
start at boot: Yes
boot order: 0
features: None

## Network
Add device interface `fedexnet` as `eth1` w/ everything as default


[x] Backup on `VMS_Backups` as `Configured, not started`
[x] run install script
[x] Backup
