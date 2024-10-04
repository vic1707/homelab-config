#!/bin/sh

DISTRIBUTION=$(
    # shellcheck disable=SC1090
    . /etc/*-release
    echo "$VERSION_CODENAME"
)

echo "- Checking  Sources lists"
if grep -Fq "deb http://download.proxmox.com/debian/pve" /etc/apt/sources.list; then
    echo "-- Source looks alredy configured - Skipping"
else
    echo "-- Adding new entry to sources.list"
    sed -i "\$adeb http://download.proxmox.com/debian/pve $DISTRIBUTION pve-no-subscription" /etc/apt/sources.list
fi
echo "- Checking Enterprise Source list"
if grep -Fq "#deb https://enterprise.proxmox.com/debian/pve" "/etc/apt/sources.list.d/pve-enterprise.list"; then
    echo "-- Entreprise repo looks already commented - Skipping"
else
    echo "-- Hiding Enterprise sources list"
    sed -i "s/^/#/" /etc/apt/sources.list.d/pve-enterprise.list
fi
echo "- Checking Ceph Enterprise Source list"
# Checking that source list file exist
if test -f "/etc/apt/sources.list.d/ceph.list"; then
    # Checking if it source is already commented or not
    if grep -Fq "#deb https://enterprise.proxmox.com/debian/ceph-quincy" "/etc/apt/sources.list.d/ceph.list"; then
        # If so do nothing
        echo "-- Ceph Entreprise repo looks already commented - Skipping"
    else
        # else comment it
        echo "-- Hiding Ceph Enterprise sources list"
        sed -i "s/^/#/" /etc/apt/sources.list.d/ceph.list
    fi
fi

## Update and upgrade ##
echo "- Updating and upgrading"
apt update && apt upgrade -y && apt dist-upgrade -y && pveam update

## Install git and fail2ban ##
echo "- Installing git, nut and fail2ban"
apt install git apcupsd fail2ban -y

## Configure fail2ban ##
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

# Enable & Restart Fail2Ban Service
echo "- Enabling fail2ban service"
systemctl enable --now fail2ban.service

# Disable SSH Service
echo "- Disable SSH service"
systemctl disable ssh sshd

# Configure UPS
echo "- Configure UPS"
cat <<EOF > /etc/apcupsd/apcupsd.conf
## apcupsd.conf v1.1 ##
UPSTYPE usb
UPSCABLE usb
DEVICE 
EOF
sed -i "s/^ISCONFIGURED=no/ISCONFIGURED=yes/" /etc/default/apcupsd
systemctl enable --now apcupsd

echo "- 'apcaccess status'"
apcaccess status

######### Add backups dir to ZFS pool #########
## Assuming that the pool is already created ##
## And is named "VMs_LXCs"                   ##
## Be aware that available space is not      ##
## representative of the actual space        ##
###############################################
# zfs create VMs_LXCs/VMS_Backups
# zfs set compression=zstd VMs_LXCs/VMS_Backups
# zfs set relatime=on VMs_LXCs/VMS_Backups
# pvesm add dir VMs_Backups --content backup --is_mountpoint yes --shared 0 --path "/VMs_LXCs/VMS_Backups"
