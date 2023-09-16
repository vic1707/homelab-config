#!/bin/bash

# Check for NON root privileges
if [ "$(id -u)" -eq 0 ]; then
  echo "This script must NOT be run as root. Please use a regular user."
  exit 1
fi

### STATIC VARIABLES ###
POD_PWD="$(dirname "${BASH_SOURCE[0]}")"
NAME=swag
VERSION=2.6.0
# shellcheck disable=SC2034
RESTART_POLICY=on-failure # no | always | on-success | on-failure | on-abnormal | on-abort | on-watchdog
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
  ## 1. SWAG_DOMAIN                         ##
  ## 2. SWAG_EMAIL                          ##
  ## 3. SUBDOMAINS                          ##
  ############################################
  if [ -z "$SWAG_DOMAIN" ]; then
    echo "SWAG_DOMAIN is not set. Please set it."
    exit 1
  fi
  if [ -z "$SWAG_EMAIL" ]; then
    echo "SWAG_EMAIL is not set. Please set it."
    exit 1
  fi
  if [ -z "$SUBDOMAINS" ]; then
    echo "SUBDOMAINS is not set. Please set it."
    exit 1
  fi
}

start() {
  # UID is user id of the current user (shouldn't be root)
  # GID is group id of the current user (shouldn't be root)
  if [ -n "$USER" ]; then
    USERNAME="$USER"
  elif [ -n "$SUDO_USER" ]; then
    USERNAME="$SUDO_USER"
  else
    echo "Could not determine current username. Please set PUID and PGID manually."
    exit 1
  fi

  podman run \
    --detach \
    --network shared \
    --name "$NAME" \
    --cap-add=NET_ADMIN \
    --volume "/mnt/config/$NAME":/config \
    --env PUID="$(id -u "$USERNAME")" \
    --env PGID="$(id -g "$USERNAME")" \
    --env TZ="Europe/Paris" \
    --env URL="$SWAG_DOMAIN" \
    --env VALIDATION="http" \
    --env EMAIL="$SWAG_EMAIL" \
    --env CERTPROVIDER="zerossl" \
    --env SUBDOMAINS="$SUBDOMAINS" \
    --env DOCKER_MODS="linuxserver/mods:swag-auto-reload|linuxserver/mods:swag-dashboard" \
    --publish 8080:80 \
    --publish 4443:443 \
    "lscr.io/linuxserver/swag:$VERSION"
  return $?
}

requirements() {
  ## Podman network `shared` must exist
  if ! podman network inspect shared &>/dev/null; then
    echo "Podman network 'shared' does not exist. Please create it."
    exit 1
  fi
  ## Put other setup lines here, like NFS mounts, etc.
  mkdir -p "/mnt/config/$NAME"
}
