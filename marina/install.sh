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
## a fresh <insert distro> installation ##
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

############################### NFS Setup ###############################
######################## Volumes to mount (fstab) #######################
# Only add lines to fstab if they don't already exist                   #
# Options are set explicitly and exhaustively (no `defaults`)           #
# to respect the principle of least privilege,                          #
# we will use the following options:                                    #
# - `rw`: read-write                                                    #
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
NFS_OPTIONS="rw,hard,noatime,nodev,nodiratime,noexec,nosuid,vers=4,minorversion=1"
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
