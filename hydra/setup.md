1. reset to defaults

#### Boot

- [x] Legacy to EFI support: Enabled
- [x] Boot order:
  - 1. UEFI USB Key
  - 2. UEFI Hard disk
  - 3. uefi network
  - 4. uefi ap efi shell
  - rest disabled

#### Security

- [x] Secureboot: Enabled
  - Secure boot mode: Custom
  - CSM support: Enabled
    - Provision factory defaults: Disabled
    - [x] Reset to Setup Mode

#### Advanced

- [x] CPU Configuration
  - [x] SMEE: Enabled
  - [x] SEV-ES ASID Space limit: 10
- [x] NB Configuration
  - [x] Determinism slider: Performance
  - [x] IOMMU : Enabled
- [x] PCIe
  - [x] SR-IOV support: Enabled
  - [x] Slot 2: 4x4x4x4
  - [x] Slot 4: 8x8
  - [x] Network Stack config
    - [x] IPV6: Disabled

#### Main

- [x] Set the clock ( MM/DD/YYYY )

#### Save & Exit

- [x] Save as user's default


### Install Proxmox

BTRFS raid 0 single drive.
email: homelab@v...
hostname: hydra.homelab - enp8s0 atlantic msi 10Gb nic
ip: --.110 - dns: 1.1.1.1

### once Proxmox installed

BIOS: 
- [x] Mode: UEFI

Proxmox:
- [x] Updates -> Repository
    - Disable : `https://enterprise.proxmox.com/debian/ceph-quincy`
    - Disable : `https://enterprise.proxmox.com/debian/pve`
    - Add : Repository: `No-subscription` (`http://download.proxmox.com/debian/pve`)
- [x] Check for updates & upgrades
- [x] Run install scripts commands
```bash
pveam update
apt install apcupsd fail2ban -y

## Configuration fail2ban
cat << EOF > /etc/fail2ban/filter.d/proxmox-virtual-environement.conf
[proxmox]
enabled = true
port = https,http,8006
filter = proxmox-virtual-environement
logpath = /var/log/daemon.log
maxretry = 3
# 1 hour
bantime = 3600
EOF

cat << EOF > /etc/fail2ban/jail.d/proxmox-virtual-environement.conf
[Definition]
failregex = pvedaemon\[.*authentication failure; rhost=<HOST> user=.* msg=.*
ignoreregex =
EOF

systemctl enable --now fail2ban.service

## Disable SSH
systemctl disable ssh sshd

## Configure UPS
cat <<EOF > /etc/apcupsd/apcupsd.conf
## apcupsd.conf v1.1 ##
UPSTYPE usb
UPSCABLE usb
DEVICE 
EOF
sed -i "s/^ISCONFIGURED=no/ISCONFIGURED=yes/" /etc/default/apcupsd
systemctl enable --now apcupsd

## Wait a bit
apcaccess status
## Ensure that voltages & everything is present
```

- [x] Reboot

local-btrfs
    - [x] ISO Images: 
        - `https://boot.netboot.xyz/ipxe/netboot.xyz.iso`
    - [x] CT Templates:
        - get alpine latest
Storage:
    Create `VMs_LXCs` raidz with all defaults options

Then in console run
```bash
zfs create VMs_LXCs/VMS_Backups
zfs set compression=zstd VMs_LXCs/VMS_Backups
zfs set relatime=on VMs_LXCs/VMS_Backups
pvesm add dir VMs_Backups --content backup --is_mountpoint yes --shared 0 --path "/VMs_LXCs/VMS_Backups"
```
