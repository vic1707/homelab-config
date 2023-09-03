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
DIST=rhel9.0
##                                      ##
## This script will:                    ##
## TODO. Install required packages      ##
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

############################# Update System #############################
echo "Updating repositories and installing packages..."
dnf clean expire-cache
dnf update -y
dnf upgrade -y
echo "Installing packages..."
dnf install -y podman nfs-utils
############################# NVIDIA Podman #############################
if [ "$MARINA_ENV" = "prod" ]; then
  # https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html#id7
  echo "Installing NVIDIA REPO..."
  curl -s -L "https://nvidia.github.io/libnvidia-container/$DIST/libnvidia-container.repo" | sudo tee /etc/yum.repos.d/nvidia-container-toolkit.repo
  echo "Installing NVIDIA Container Toolkit..."
  dnf update -y
  dnf install -y nvidia-container-toolkit
  # allow non root containers to access the GPU
  sed -i 's/^#no-cgroups = false/no-cgroups = true/;' /etc/nvidia-container-runtime/config.toml
fi
########################### Configure services ##########################
echo "Configuring services..."
## Enable and start NFS
systemctl enable nfs-server.service
systemctl start nfs-server.service
## disable sshd
systemctl disable sshd.service
systemctl stop sshd.service
############################## Podman Setup #############################
podman network create shared # used for communication between containers
############################### NFS Setup ###############################
######################## Volumes to mount (fstab) #######################
# Only add lines to fstab if they don't already exist                   #
# Options are set explicitly and exhaustively (no `defaults`)           #
# to respect the principle of least privilege,                          #
# we will use the following options:                                    #
# - `rw`: read-write                                                    #
# - `acl`: enable access control lists                                  #
# - `hard`: fail after 3 retries                                        #
# - `noatime`: don't update access time                                 #
# - `nodev`: don't allow device files to be created                     #
# - `nodiratime`: don't update directory access time                    #
# - `noexec`: don't allow execution of binaries on the mounted volume   #
# - `nosuid`: don't allow set-user-identifier or set-group-identifier   #
# - `vers=4`: use NFSv4                                                 #
# - `minorversion=1`: use NFSv4.1                                       #
#########################################################################
## 1. /mnt/config => 10.0.0.2:/mnt/Marina-config/Configs/$MARINA_ENV   ##
## 2. /mnt/bhulk => 10.0.0.2:/mnt/Bhulk/Marina-Bhulk/$MARINA_ENV       ##
#########################################################################
NFS_OPTIONS="rw,acl,hard,noatime,nodev,nodiratime,noexec,nosuid,vers=4,minorversion=1"
echo "Configuring config volume..."
if ! grep -q "/mnt/config" /etc/fstab; then
  echo "Adding config volume to fstab..."
  echo "10.0.0.2:/mnt/Marina-config/Configs/$MARINA_ENV /mnt/config nfs $NFS_OPTIONS 0 0" >> /etc/fstab
fi

echo "Mounting bhulk volume..."
if ! grep -q "/mnt/bhulk" /etc/fstab; then
  echo "Adding bhulk volume to fstab..."
  echo "10.0.0.2:/mnt/Bhulk/Marina-Bhulk/$MARINA_ENV /mnt/bhulk nfs $NFS_OPTIONS 0 0" >> /etc/fstab
fi
# reload fstab
mount -a
