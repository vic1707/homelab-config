### Proxmox
Name: bhulk
Start on boot: Yes
Startup order: 1
---
mount TrueNAS CORE ISO
GuestOS: Other
---
Machine: q35
BIOS: OVMF UEFI
Add UEFI BOOT DEVICE
---
Bus/Device: SCSI
SSD Emulation: on
---
2 CPU cores
Type: HOST
---
Memory: 128Gb => 131 072 Mb
Ballooning => NO
---
Network
birdge: `vmbr0`
Model: VirtIO
MAC: `BC:24:11:4C:5F:4E`
Firewall: NO
MTU 1


### Options
Boot order: only scsi0 (after install, for install ide2 should be first)
use tablet for pointers: No
Hotplug: Disabled
### Hardware
Add device interface `fedexnet`, virtIO, MTU 1, no FW, MAC: `F6:3A:7B:43:B8:2C`
Pass in
    - SAS Controller
    - Both 128Gb NVME
With options:
    All functions: Yes
    ROM-Bar: Yes
    PCI-Express: Yes


[x] Backup on `VMS_Backups` as `Configured, not started`

> It is probably needed to access VM's BIOS and disable secureboot for first install.

[x] Install truenas and ensure everything is fine
[x] Backup
