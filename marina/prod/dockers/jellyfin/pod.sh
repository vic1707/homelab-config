#!/bin/bash

# Check for NON root privileges
if [ "$(id -u)" -eq 0 ]; then
  echo "This script must NOT be run as root. Please use a regular user."
  exit 1
fi

### STATIC VARIABLES ###
# POD_PWD="$(dirname "${BASH_SOURCE[0]}")"
NAME=jellyfin
VERSION=10.8.11
# shellcheck disable=SC2034
RESTART_POLICY=on-failure # no | always | on-success | on-failure | on-abnormal | on-abort | on-watchdog
########################

source_env() {
  ## Nothing to do here
  true;
}

start() {
  podman run \
    --privileged \
    --detach \
    --network shared \
    --name "$NAME" \
    --publish 8096:8096/tcp \
    --env TZ="Europe/Paris" \
    --volume "/mnt/config/$NAME":/config:Z,rw \
    --volume "/media/$NAME":/media:ro \
    --device nvidia.com/gpu=all \
    "docker.io/jellyfin/jellyfin:$VERSION"
  return $?
}

requirements() {
  ## Check for sudo privileges
  if ! sudo -v; then
    echo "You must have sudo privileges to run this script."
    exit 1
  fi

  ## NVIDIA container env should be created and configured
  # if `nvidia-ctk` doesn't exist, err
  if ! command -v nvidia-ctk &>/dev/null; then
    echo "NVIDIA Container Toolkit is not installed. Please install it."
    exit 1
  fi
  # if /etc/cdi/nvidia.yaml doesn't exist, try create it
  if [ ! -f /etc/cdi/nvidia.yaml ]; then
    echo "NVIDIA Container Toolkit configuration file is not present. Trying to create it..."
    if ! sudo nvidia-ctk cdi generate --output=/etc/cdi/nvidia.yaml; then
      echo "Failed to create NVIDIA Container Toolkit configuration file. Please create it manually."
      exit 1
    fi
  fi

  ## Put other setup lines here, like NFS mounts, etc.
  mkdir -p "/mnt/config/$NAME"

  echo "Configuring JellyfinMedia volumes..."
  RELOAD_FSTAB=0
  NFS_OPTIONS="ro,acl,hard,noatime,nodev,nodiratime,noexec,nosuid,vers=4,minorversion=1"
  SHARES=( "Animes" "Movies" "Music" "NSFW" "Scans" "Shows" )
  for share in "${SHARES[@]}"; do
    if ! grep -q "/media/$NAME/$share" /etc/fstab; then
      RELOAD_FSTAB=1
      echo "Adding $share volume to fstab..."
      sudo mkdir -p "/media/$NAME/$share"
      echo "10.0.0.2:/mnt/Bhulk/Medias/$share /media/$NAME/$share nfs $NFS_OPTIONS 0 0" | sudo tee -a /etc/fstab
    fi
  done

  if [ $RELOAD_FSTAB -eq 1 ]; then
    echo "Reloading fstab..."
    sudo mount -a
    sudo systemctl daemon-reload
    return $?
  fi
  return 0
}
