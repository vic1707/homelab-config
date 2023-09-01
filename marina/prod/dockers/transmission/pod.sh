#!/bin/sh

# Check for NON root privileges
if [ "$(id -u)" -eq 0 ]; then
  echo "This script must NOT be run as root. Please use a regular user."
  exit 1
fi

### STATIC VARIABLES ###
PWD=$(cd "$(dirname "$0")" && pwd && cd - > /dev/null || exit 1)
NAME=transmission
VERSION=5
# shellcheck disable=SC2034
RESTART_POLICY="on-failure"
########################

source_env() {
  # Load environment variables
  # if .env file is not present, exit on failure
  echo "Loading environment variables from .env file..."
  if [ -f "$PWD/.env" ]; then
    . "$PWD/.env" || exit 1
  else
    echo "File not found: $PWD/.env"
    exit 1
  fi

  ####### Check for required variables #######
  ## 1. OVPN_PROVIDER: 'PIA' | 'WINDSCRIBE' ##
  ## 2. OVPN_USR                            ##
  ## 3. OVPN_PWD                            ##
  ## 4. OVPN_CONFIG: RTFM                   ##
  ## 5. OVPN_PORT: 1-65535                  ##
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
  if [ -z "$OVPN_PORT" ] || [ "$OVPN_PORT" -lt 1 ] || [ "$OVPN_PORT" -gt 65535 ]; then
    echo "
    OVPN_PORT is not properly set.
    Please set it to a value between 1 and 65535.
    OVPN_PORT: \`$OVPN_PORT\`
    "
    exit 1
  fi
}

start() {
  podman run \
    --name "$NAME" \
    --cap-add=NET_ADMIN -d \
    -v "/mnt/bhulk/$NAME":/data \
    -v /mnt/config/:/config \
    -e WEBPROXY_ENABLED=false \
    -e TRANSMISSION_WEB_UI=flood-for-transmission \
    -e OPENVPN_PROVIDER="$OVPN_PROVIDER" \
    -e OPENVPN_CONFIG="$OVPN_CONFIG" \
    -e OPENVPN_USERNAME="$OVPN_USR" \
    -e OPENVPN_PASSWORD="$OVPN_PWD" \
    --log-driver json-file \
    --log-opt max-size=10m \
    -p "$OVPN_PORT:9091" \
    docker.io/haugene/transmission-openvpn:$VERSION
}
