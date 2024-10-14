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
Pass in - SAS Controller - Both 128Gb NVME
With options:
All functions: Yes
ROM-Bar: Yes
PCI-Express: Yes

[x] Backup on `VMS_Backups` as `Configured, not started`

> It is probably needed to access VM's BIOS and disable secureboot for first install.

[x] Install truenas and ensure everything is fine
[x] Backup

## Initial Setup

### Accounts

[x] change root password
[x] Create `created-users` with authorization for samba auth
[x] Create users (locking prevents SSH with keys)

-   `vic1707`: no email, ZSH, permits sudo, samba auth, paste ssh pub (ensure owning of home dir)
-   `marina`: no email, ZSH, lock user

### System

[x] GUI only available through the LAN (not fedex)
[x] TZ: Paris
[x] No telemerty

[x] System dataset is boot pool

#### Advanced

[x] tick, `show advanced`/`console messages`/`Autotune`

### Network

[x] set both static interfaces, MTU 1500, no DHCP
[x] Set hostname to bhulk.homelab

### Tasks

[x] SMART tests: All disks - LONG: 3AM, 1st of the month - SHORT: 3AM, 8,15,22,28th of the month
[x] Edit scrubs to be - 0 threshhold - 1 & 15th of month - 6AM

### Services
Start auto - Enabled
[x] SSH - Port `XXXXXX` - No root login - No password auth - No weak ciphers
[x] NFS - Nb Servers: 2 - both logs

### NFS Mounts
/mnt/Bhulk/Media/*
/mnt/Bhulk/VMs/Marina
/mnt/Fluffy/Marina
Options: 
 - all dirs
 - enabled
 - map all user: marina
 - map all group: created-users
 - authorized nets: 10.0.0.0/28
 - authorized IP: 10.0.0.3

### Storage
TODO: Permissions: Big Fucking Mess 
