#!/bin/bash

# Check for NON root privileges
if [ "$(id -u)" -eq 0 ]; then
  echo "This script must NOT be run as root. Please use a regular user."
  exit 1
fi

### STATIC VARIABLES ###
POD_PWD="$(dirname "${BASH_SOURCE[0]}")"
NAME=transmission
VERSION=5
# shellcheck disable=SC2034
RESTART_POLICY="on-failure"
########################

source_env() {
  # Load environment variables
  # if .env file is not present, exit on failure
  echo "Loading environment variables from .env file..."
  if [ -f "$POD_PWD/.env" ]; then
    . "$POD_PWD/.env" || exit 1
  else
    echo "File not found: $POD_PWD/.env"
    exit 1
  fi

  ####### Check for required variables #######
  ## 1. OVPN_PROVIDER: 'PIA' | 'WINDSCRIBE' ##
  ## 2. OVPN_USR                            ##
  ## 3. OVPN_PWD                            ##
  ## 4. OVPN_CONFIG: RTFM                   ##
  ############################################
  if [ -z "$OVPN_PROVIDER" ] || [ "$OVPN_PROVIDER" != "PIA" ] && [ "$OVPN_PROVIDER" != "WINDSCRIBE" ]; then
    echo "
    OVPN_PROVIDER is not properly set.
    Please set it to 'PIA' | 'WINDSCRIBE'.
    OVPN_PROVIDER: \`$OVPN_PROVIDER\`
    "
    exit 1
  fi
  if [ -z "$OVPN_USR" ]; then
    echo "OVPN_USR is not set. Please set it."
    exit 1
  fi
  if [ -z "$OVPN_PWD" ]; then
    echo "OVPN_PWD is not set. Please set it."
    exit 1
  fi
  if [ -z "$OVPN_CONFIG" ]; then
    echo "OVPN_CONFIG is not set. Please set it."
    exit 1
  fi
}

start() {
  podman run \
    --detach \
    --network shared \
    --name "$NAME" \
    --volume "/mnt/bhulk/$NAME/":/data \
    --volume "/mnt/config/$NAME/":/config \
    --sysctl net.ipv6.conf.all.disable_ipv6=0 \
    --env TZ="Europe/Paris" \
    --env ENABLE_UFW=true \
    --env WEBPROXY_ENABLED=false \
    --env TRANSMISSION_WEB_UI=flood-for-transmission \
    `# allows restart on VPN failure` \
    --env OPENVPN_OPTS="--inactive 3600 --ping 10 --ping-exit 60" \
    --env OPENVPN_PROVIDER="$OVPN_PROVIDER" \
    --env OPENVPN_CONFIG="$OVPN_CONFIG" \
    --env OPENVPN_USERNAME="$OVPN_USR" \
    --env OPENVPN_PASSWORD="$OVPN_PWD" \
    `# wish i could disable these` \
    --privileged \
    --env CREATE_TUN_DEVICE=false \
    --device /dev/net/tun \
    docker.io/haugene/transmission-openvpn:$VERSION
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
}
