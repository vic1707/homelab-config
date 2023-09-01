#!/bin/sh

# Check for NON root privileges
if [ "$(id -u)" -eq 0 ]; then
  echo "This script must NOT be run as root. Please use a regular user."
  exit 1
fi

### STATIC VARIABLES ###
PWD=$(cd "$(dirname "$0")" && pwd && cd - > /dev/null || exit 1)
NAME=
VERSION=
# shellcheck disable=SC2034
RESTART_POLICY= # no | always | on-success | on-failure | on-abnormal | on-abort | on-watchdog
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
  ## 1. ...                                 ##
  ############################################
}

start() {
  # ...
  podman run \
    -d \
    --name "$NAME" \
    "container:$VERSION"
}

requirements() {
  ## Put setup lines here, like NFS mounts, etc.
}
