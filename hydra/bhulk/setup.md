### Proxmox

Name: bhulk
Start on boot: Yes
Startup order: 1

---

mount TrueNAS SCALE ISO
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

### [x] Dashboard
Do whatever you want

### [x] Accounts

[x] change admin password
[x] Create `created-users` with all defaults
[x] Create users (locking prevents SSH with keys)

-   `vic1707`: no email, tmux, permits all sudo cmd, samba auth, paste ssh pub (ensure owning of home dir), auxialiary group: truenas admin
-   `marina`: no email, nologin, lock user

### [x] System

TODO: Can't do that ??
<!-- [x] GUI only available through the LAN (not fedex) -->
[x] TZ: Paris
[x] No telemerty
[x] Show Console Messages
[x] redirect HTTP to HTTPS

#### [x] Advanced

[x] System dataset is boot pool
[x] untick `Show Text Console without Password Prompt`

### [x] Network
[x] Set hostname to bhulk.homelab
[x] 1.1.1.1 DNS
[x] only updates can outbound

Nothing to do for interfaces it seems but just in case:
[x] set both static interfaces, MTU 1500, no DHCP

### [x] Data Protection

[x] SMART tests: All disks - LONG: 3AM, 1st of the month - SHORT: 3AM, 8,15,22,29th of the month
[x] Edit scrubs to be - 0 threshhold - 1 & 15th of month - 6AM

### Services
Start auto - Enabled
[x] SSH - Port `XXXXXX` - No root login - No password auth - No weak ciphers
[x] NFS - Nb Servers: auto - both logs, NFS v4, NFSv3 ownership model for NFSv4

### NFS Mounts
/mnt/Bhulk/Media/* - (RO)
/mnt/Bhulk/VMs/Marina
/mnt/Fluffy/Marina
Options: 
 - enabled
 - map all user: marina
 - map all group: created-users
 - authorized nets: 10.0.0.0/28
 - authorized IP: 10.0.0.3

### [x] Storage
TODO: Permissions: Big Fucking Mess 
Note: Home folder should be 700 and 600 for .ssh in order to allow ssh 
