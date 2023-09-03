#!/bin/bash

# Check for NON root privileges
if [ "$(id -u)" -eq 0 ]; then
  echo "This script must NOT be run as root. Please use a regular user."
  exit 1
fi

### STATIC VARIABLES ###
# POD_PWD="$(dirname "${BASH_SOURCE[0]}")"
NAME=jellyfin
VERSION=10.8.10
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
    --env TZ="Europe/Paris" \
    --volume "/mnt/config/$NAME/":/config \
    --volume /mnt/jellyfin_medias:/media:ro \
    --env NVIDIA_VISIBLE_DEVICES=all \
    --gpus all \
    "lscr.io/linuxserver/jellyfin:$VERSION"
  return $?
}

requirements() {
  ## Podman network `shared` must exist
  if ! podman network inspect shared &>/dev/null; then
    echo "Podman network 'shared' does not exist. Please create it."
    exit 1
  fi
  ## Put other setup lines here, like NFS mounts, etc.
  mkdir -p "/mnt/bhulk/$NAME"
  mkdir -p "/mnt/config/$NAME"

  echo "Configuring config volume..."
  NFS_OPTIONS="ro,acl,hard,noatime,nodev,nodiratime,noexec,nosuid,vers=4,minorversion=1"
  if ! grep -q "/mnt/jellyfin_medias" /etc/fstab; then
    echo "Adding config volume to fstab..."
    echo "10.0.0.2:/mnt/Bhulk/Medias /mnt/jellyfin_medias nfs $NFS_OPTIONS 0 0" >> /etc/fstab
    # reload fstab
    echo "Reloading fstab, please enter root password..."
    sudo mount -a
    return $?
  fi
}
