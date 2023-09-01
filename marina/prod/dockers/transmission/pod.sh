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
  ## 5. TRANSMISSION_UI_PORT: 1-65535       ##
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
  if [ -z "$TRANSMISSION_UI_PORT" ] || [ "$TRANSMISSION_UI_PORT" -lt 1 ] || [ "$TRANSMISSION_UI_PORT" -gt 65535 ]; then
    echo "
    TRANSMISSION_UI_PORT is not properly set.
    Please set it to a value between 1 and 65535.
    TRANSMISSION_UI_PORT: \`$TRANSMISSION_UI_PORT\`
    "
    exit 1
  fi
}

start() {
  # TODO: check if `--device /dev/net/tun` and `CREATE_TUN_DEVICE=false` are needed
  podman run \
    -d \
    --name "$NAME" \
    --cap-add=NET_ADMIN \
    -v "/mnt/bhulk/$NAME/":/data \
    -v "/mnt/config/$NAME/":/config \
    -e WEBPROXY_ENABLED=false \
    -e TRANSMISSION_WEB_UI=flood-for-transmission \
    -e OPENVPN_PROVIDER="$OVPN_PROVIDER" \
    -e OPENVPN_CONFIG="$OVPN_CONFIG" \
    -e OPENVPN_USERNAME="$OVPN_USR" \
    -e OPENVPN_PASSWORD="$OVPN_PWD" \
    -e CREATE_TUN_DEVICE=false \
    --log-driver json-file \
    --log-opt max-size=10m \
    --device /dev/net/tun \
    -p "$TRANSMISSION_UI_PORT:9091" \
    docker.io/haugene/transmission-openvpn:$VERSION
}

requirements() {
  mkdir -p /mnt/bhulk/"$NAME"
  mkdir -p /mnt/config/"$NAME"
}
