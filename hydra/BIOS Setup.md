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


### Proxmox

BTRFS raid 0 single drive.
email: homelab@v...
hostname: hydra.homelab - enp8s0 atlantic msi 10Gb nic
ip: --.110 - dns: 1.1.1.1


