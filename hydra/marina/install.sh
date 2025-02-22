#!/bin/sh

## Ensure you are running the latest kernel
## Reinstall the VM if not sure

##########################################
## Install script for Marina            ##
##                                      ##
## This script is meant to be run on    ##
## a fresh AlmaLinux:9 installation     ##
##                                      ##
## This script will:                    ##
## 1. Install required packages         ##
##  a. podman                           ##
##  b. nfs client                       ##
##  c. rsync                            ##
##  d. atim/bottom                      ##
##  e. podman-compose                   ##
## 2. NVIDIA driver                     ##
## 3. Configure NFS volumes             ##
##########################################

PWD=$(cd "$(dirname "$0")" && pwd && cd - > /dev/null || exit 1)

# Check for root privileges
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root. Please use sudo."
    exit 1
fi

# check if repo is up to date, if not error and ask to pull
if git fetch && git status -uno | grep 'behind'; then
    echo "Error updating repo. Please pull manually."
    exit 1
fi

################################ Update System ################################
echo "Updating repositories and installing packages..."
echo "Installing Epel..."
dnf install -y epel-release
echo "Installing other packages..."
dnf install -y podman nfs-utils rsync
dnf copr enable -y atim/bottom
dnf install bottom -y
dnf upgrade -y
################################ Podman compose ################################
echo "Manually installing podman compose as dnf version is too old"
# TODO: watch https://github.com/containers/podman-compose/issues/1024
dnf install -y python3-dotenv
curl -o /usr/bin/podman-compose https://raw.githubusercontent.com/containers/podman-compose/main/podman_compose.py
chmod +x /usr/bin/podman-compose
################################ NVIDIA Podman ################################
# ATM it is 560.28.03
echo "Installing NVIDIA Driver..."
dnf config-manager --add-repo "https://developer.download.nvidia.com/compute/cuda/repos/rhel9/x86_64/cuda-rhel9.repo"
dnf module install -y nvidia-driver:latest-dkms
# https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html#id7
echo "Installing NVIDIA Container Toolkit..."
dnf config-manager --add-repo "https://nvidia.github.io/libnvidia-container/stable/rpm/nvidia-container-toolkit.repo"
dnf install -y nvidia-container-toolkit
# allow non root containers to access the GPU
sed -i 's/^#no-cgroups = false/no-cgroups = true/;' /etc/nvidia-container-runtime/config.toml

### Used later by jellyfin and nvidia cuda, installing the nvidia selinux policy didn't work properly with jellyfin
setsebool -P container_use_devices=1
############################# NVIDIA CDI Service #############################
echo "Creating systemd service for NVIDIA CDI configuration..."
cat << EOF > /etc/systemd/system/nvidia-cdi-generator.service
[Unit]
Description=Generate NVIDIA CDI Configuration
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/usr/bin/nvidia-ctk cdi generate --output=/etc/cdi/nvidia.yaml

[Install]
WantedBy=multi-user.target
EOF

systemctl enable nvidia-cdi-generator.service
########################### End NVIDIA CDI Service ###########################
############################# Additionnal Settings ############################
echo "Configuring additional settings..."
## Hostname
hostnamectl set-hostname marina
## Disable IPv6
echo "net.ipv6.conf.all.disable_ipv6=1" >> /etc/sysctl.conf
################################## NFS Setup ##################################
########################### Volumes to mount (fstab) ##########################
# Only add lines to fstab if they don't already exist                         #
# Options are set explicitly and exhaustively (no `defaults`)                 #
# to respect the principle of least privilege,                                #
# we will use the following options:                                          #
# - `rw`: read-write                                                          #
# - `acl`: enable access control lists                                        #
# - `hard`: fail after 3 retries                                              #
# - `noatime`: don't update access time                                       #
# - `nodev`: don't allow device files to be created                           #
# - `nodiratime`: don't update directory access time                          #
# - `noexec`: don't allow execution of binaries on the mounted volume         #
# - `nosuid`: don't allow set-user-identifier or set-group-identifier         #
# - `vers=4`: use NFSv4                                                       #
# - `minorversion=1`: use NFSv4.1                                             #
###############################################################################
## 1. /mnt/remote-config => 10.0.0.2:/mnt/Fluffy/Marina                      ##
## 2. /mnt/bhulk => 10.0.0.2:/mnt/Bhulk/VMs                                  ##
###############################################################################
NFS_OPTIONS="rw,acl,hard,noatime,nodev,nodiratime,noexec,nosuid,vers=4,minorversion=1"
echo "Configuring config volume..."
if ! grep -q "/mnt/remote-config" /etc/fstab; then
    mkdir -p /mnt/remote-config
    echo "Adding config volume to fstab..."
    echo "10.0.0.2:/mnt/Fluffy/Marina /mnt/remote-config nfs $NFS_OPTIONS 0 0" >> /etc/fstab
fi

echo "Mounting bhulk volume..."
if ! grep -q "/mnt/bhulk" /etc/fstab; then
    mkdir -p /mnt/bhulk
    echo "Adding bhulk volume to fstab..."
    echo "10.0.0.2:/mnt/Bhulk/VMs/Marina /mnt/bhulk nfs $NFS_OPTIONS 0 0" >> /etc/fstab
fi
# reload fstab
mount -a
systemctl daemon-reload

# Setup sync between config volume and local config in real time
echo "Setting up config sync using rsync..."
mkdir -p /mnt/config
# sync existing files from remote-config to config
rsync -av --delete /mnt/remote-config/ /mnt/config
# give permissions back to user
chown -R "$SUDO_USER":"$SUDO_USER" /mnt/config
# sync new files from remote-config to config on regular intervals and keep a logfile
echo "0 5 * * * root \
  bash -c 'temp_log_file=\"/root/rsync_log_\$(date +\%Y\%m\%d\%H\%M\%S).log\"; \
  mv /mnt/remote-config/rsync.log \"\$temp_log_file\"; \
  rsync -aq --no-group --no-owner --delete --log-file=\"\$temp_log_file\" /mnt/config/ /mnt/remote-config; \
  mv \$temp_log_file /mnt/remote-config/rsync.log'" >> /etc/crontab
# the above command will run every 5 minutes
systemctl restart crond.service

## Important reminder
firewall-cmd --zone=public --permanent --add-port=8080/tcp  # caddy
firewall-cmd --zone=public --permanent --add-port=4443/tcp  # caddy
firewall-cmd --zone=public --permanent --add-port=51820/udp # wireguard
firewall-cmd --reload

# shellcheck disable=SC2016 # expected
echo 'do not forget to check that everything is good by running
    > podman run --rm -u "$(id -u):$(id -g)" --cap-drop=ALL --device nvidia.com/gpu=all docker.io/nvidia/cuda:12.6.2-base-ubuntu24.04 nvidia-smi
on your next boot'

# sometimes git repo gets owned by root
# preventing user from pulling
# this will fix it
chown -R "$SUDO_USER":"$SUDO_USER" "/home/$SUDO_USER"

# Reboot confirmation
echo "Configuration completed. Do you want to reboot now? (Y/N)"
read -r choice
if [ "$choice" = "Y" ] || [ "$choice" = "y" ]; then
    echo "Rebooting..."
    sleep 3
    reboot
fi

echo "Reboot cancelled. You can manually reboot the system when ready."
