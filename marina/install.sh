#!/bin/sh

source_env() {
  if [ -f "$1" ]; then
    . "$1"
    return $?
  else
    echo "File not found: $1"
    exit 1
  fi
}

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
##  opt(prod). NVIDIA driver            ##
## 2. Configure NFS volumes             ##
##########################################

PWD=$(cd "$(dirname "$0")" && pwd && cd - > /dev/null || exit 1)

# Check for root privileges
if [ "$(id -u)" -ne 0 ]; then
  echo "This script must be run as root. Please use sudo."
  exit 1
fi

### TODO: parse as arg or choice
# Load environment variables
# if .env file is not present, exit on failure
echo "Loading environment variables from .env file..."
source_env "$PWD/.env" || exit 1

########## Check for required variables ##########
## 1. MARINA_ENV: 'prod' | 'staging' | 'random' ##
##################################################
if [ -z "$MARINA_ENV" ] || [ "$MARINA_ENV" != "prod" ] && [ "$MARINA_ENV" != "staging" ] && [ "$MARINA_ENV" != "random" ]; then
  echo "
  MARINA_ENV is not properly set.
  Please set it to 'prod' | 'staging' | 'random'.
  MARINA_ENV: \`$MARINA_ENV\`
  "
  exit 1
fi

################################ Update System ################################
echo "Updating repositories and installing packages..."
dnf update -y
dnf upgrade -y
echo "Installing packages..."
dnf install -y podman nfs-utils rsync
################################ NVIDIA Podman ################################
if [ "$MARINA_ENV" = "prod" ]; then
  echo "Blacklisting nouveau..."
  echo "blacklist nouveau" | sudo tee /etc/modprobe.d/blacklist-nouveau.conf
  echo 'omit_drivers+=" nouveau "' | sudo tee /etc/dracut.conf.d/blacklist-nouveau.conf
  ######
  echo "Installing Epel..."
  dnf install -y epel-release
  dnf update -y
  dnf upgrade -y
  echo "Installing NVIDIA Drivers..."
  dnf config-manager --add-repo "https://developer.download.nvidia.com/compute/cuda/repos/rhel9/$(uname -i)/cuda-rhel9.repo"
  ## possible dependencies
  dnf install -y "kernel-headers-$(uname -r)" "kernel-devel-$(uname -r)" tar bzip2 make automake gcc gcc-c++ pciutils elfutils-libelf-devel libglvnd-opengl libglvnd-glx libglvnd-devel acpid pkgconfig dkms
  ## driver itself
  dnf module install -y nvidia-driver:latest-dkms
  # regenerate initramfs
  dracut --regenerate-all --force
  depmod -a
  ## Test with `nvidia-smi`
  # https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html#id7
  echo "Installing NVIDIA REPO..."
  dnf config-manager --add-repo "https://nvidia.github.io/libnvidia-container/stable/rpm/nvidia-container-toolkit.repo"
  echo "Installing NVIDIA Container Toolkit..."
  dnf update -y
  dnf install -y nvidia-container-toolkit
  # configure nvidia-container-runtime
  # TODO: find a way to do it here, needs to load the driver first
  # nvidia-ctk cdi generate --output=/etc/cdi/nvidia.yaml
  # check success with `nvida-ctk cdi list`
  # allow non root containers to access the GPU
  sed -i 's/^#no-cgroups = false/no-cgroups = true/;' /etc/nvidia-container-runtime/config.toml
  # REBOOT IS REQUIRED
  # Test with `podman run --rm --device nvidia.com/gpu=all docker.io/nvidia/cuda:11.6.2-base-ubuntu20.04 nvidia-smi`
fi
############################## Configure services #############################
echo "Configuring services..."
## disable sshd
systemctl disable sshd.service
systemctl stop sshd.service
############################# Additionnal Settings ############################
echo "Configuring additional settings..."
## Hostname
hostnamectl set-hostname "marina-$MARINA_ENV"
## Disable IPv6
echo "net.ipv6.conf.all.disable_ipv6=1" >> /etc/sysctl.conf
################################# Podman Setup ################################
echo "Configuring podman..."
# else it's created for root user only
runuser -u "$SUDO_USER" -- podman network create shared
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
## 1. /mnt/remote-config => 10.0.0.2:/mnt/Marina-config/Configs/$MARINA_ENV  ##
## 2. /mnt/bhulk => 10.0.0.2:/mnt/Bhulk/Marina-Bhulk/$MARINA_ENV             ##
###############################################################################
NFS_OPTIONS="rw,acl,hard,noatime,nodev,nodiratime,noexec,nosuid,vers=4,minorversion=1"
echo "Configuring config volume..."
if ! grep -q "/mnt/remote-config" /etc/fstab; then
  mkdir -p /mnt/remote-config
  echo "Adding config volume to fstab..."
  echo "10.0.0.2:/mnt/Marina-config/Configs/$MARINA_ENV /mnt/remote-config nfs $NFS_OPTIONS 0 0" >> /etc/fstab
fi

echo "Mounting bhulk volume..."
if ! grep -q "/mnt/bhulk" /etc/fstab; then
  mkdir -p /mnt/bhulk
  echo "Adding bhulk volume to fstab..."
  echo "10.0.0.2:/mnt/Bhulk/Marina-Bhulk/$MARINA_ENV /mnt/bhulk nfs $NFS_OPTIONS 0 0" >> /etc/fstab
fi
# reload fstab
mount -a
systemctl daemon-reload

# Setup sync between config volume and local config in real time
echo "Setting up config sync using rsync..."
mkdir -p /mnt/config
chown "$SUDO_USER":"$SUDO_USER" /mnt/config
# sync existing files from remote-config to config
rsync -av --delete /mnt/remote-config/ /mnt/config
# sync new files from remote-config to config on regular intervals
echo "*/5 * * * * rsync -av --delete /mnt/config/ /mnt/remote-config" >> /etc/crontab
# the above command will run every 5 minutes
systemctl restart crond.service

## Important reminder
if [ "$MARINA_ENV" = "prod" ]; then
  echo "
    IMPORTANT: do not forget to run
    \`nvidia-ctk cdi generate --output=/etc/cdi/nvidia.yaml\`
    after rebooting the system.
  "
fi

# Reboot confirmation
echo "Configuration completed. Do you want to reboot now? (Y/N)"
read -r choice
if [ "$choice" = "Y" ] || [ "$choice" = "y" ]; then
  echo "Rebooting..."
  sleep 3
  reboot
fi

echo "Reboot cancelled. You can manually reboot the system when ready."
