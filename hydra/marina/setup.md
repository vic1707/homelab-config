### Proxmox

Name: marina
Start on boot: Yes
Startup order: 2
Startup delay: 300
---
mount netboot.xyz ISO
GuestOS: Linux, latest kernel
---
Machine: q35
BIOS: OVMF UEFI
Add UEFI BOOT DEVICE
---
Bus/Device: SCSI
64Gb
SSD Emulation: on
---
8 CPU cores
Type: HOST
---
Memory: 24Gb => 24 576 Mb
Ballooning => NO
---
Network
birdge: `fedexnet`
Model: VirtIO
MAC: `0A:A8:F3:7E:9D:64`
Firewall: NO
MTU: 1

### Options
Boot order: only scsi0 (after install, for install ide2 should be first)
use tablet for pointers: No
Hotplug: Disabled
### Hardware
Pass in
    - p2000
With options:
    All functions: Yes
    ROM-Bar: Yes
    PCI-Express: Yes


[x] Backup on `VMS_Backups` as `Configured, not started`

> It is probably needed to access VM's BIOS and disable secureboot for first install.

[x] Install almalinux and ensure everything is fine
Alma config:
 - No root account
 - Software selection: Minimal install
 - KDUMP: Enabled
 - No security profile

[x] Backup

### Initial basic setup
Install `git`, ssh keys, and change password
    - **ON LOCAL COMPUTER**: `ssh-copy-id -i ~/.ssh/marina-prod.pub marina@10.0.0.3`
    - `sudo dnf install -y git`
    - `git clone https://github.com/vic1707/homelab-config`
    - `passwd`
    - Ensure everything is up to date
    - run `ssh.sh` script

### Install
Re-ensure everything is up to date (especially kernel & Co.)
run `install.sh`
