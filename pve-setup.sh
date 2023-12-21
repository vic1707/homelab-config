#!/bin/sh

DISTRIBUTION=$(. /etc/*-release;echo "$VERSION_CODENAME")

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
    sed -i 's/^/#/' /etc/apt/sources.list.d/pve-enterprise.list
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
        sed -i 's/^/#/' /etc/apt/sources.list.d/ceph.list
    fi
fi

## Update and upgrade ##
echo "- Updating and upgrading"
apt update && apt upgrade -y && apt dist-upgrade -y && pveam update

## Install git and fail2ban ##
echo "- Installing git and fail2ban"
apt install git fail2ban -y

## Configure fail2ban ##
cat <<EOF > /etc/fail2ban/filter.d/proxmox-virtual-environement.conf
[proxmox]
enabled = true
port = https,http,8006
filter = proxmox-virtual-environement
logpath = /var/log/daemon.log
maxretry = 3
# 1 hour
bantime = 3600
EOF

cat <<EOF > /etc/fail2ban/jail.d/proxmox-virtual-environement.conf
[Definition]
failregex = pvedaemon\[.*authentication failure; rhost=<HOST> user=.* msg=.*
ignoreregex =
EOF

# Enable & Restart Fail2Ban Service
echo "- Restarting fail2ban service"
systemctl enable fail2ban.service
systemctl restart fail2ban.service

## Deny root SSH and various hardening ##
sed -i 's/PermitRootLogin yes/PermitRootLogin no/g' /etc/ssh/sshd_config
RDM_SSH_PORT=$(shuf -n 1 -i 10000-65500)
sed -i "s/#Port 22/Port $RDM_SSH_PORT/g" /etc/ssh/sshd_config
sed -i 's/#ListenAddress 0.0.0.0/ListenAddress 0.0.0.0/g' /etc/ssh/sshd_config
sed -i 's/#AddressFamily any/AddressFamily inet/g' /etc/ssh/sshd_config
sed -i 's/#PermitEmptyPasswords no/PermitEmptyPasswords no/g' /etc/ssh/sshd_config
sed -i 's/#LogLevel INFO/LogLevel VERBOSE/g' /etc/ssh/sshd_config
sed -i 's/#MaxAuthTries 6/MaxAuthTries 3/g' /etc/ssh/sshd_config
sed -i 's/#MaxSessions 10/MaxSessions 3/g' /etc/ssh/sshd_config
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/g' /etc/ssh/sshd_config
sed -i 's/#MaxStartups 10:30:100/MaxStartups 3:50:3/g' /etc/ssh/sshd_config
sed -i 's/#TCPKeepAlive yes/TCPKeepAlive yes/g' /etc/ssh/sshd_config

# Restart SSH Service
echo "- Restarting SSH service"
systemctl restart ssh sshd

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
