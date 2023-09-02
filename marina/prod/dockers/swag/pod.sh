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
  ############################################
  if [ -z "$SWAG_DOMAIN" ]; then
    echo "SWAG_DOMAIN is not set. Please set it."
    exit 1
  fi
  if [ -z "$SWAG_EMAIL" ]; then
    echo "SWAG_EMAIL is not set. Please set it."
    exit 1
  fi
}

start() {
  podman run \
    --detach \
    --name "$NAME" \
    --cap-add=NET_ADMIN \
    --volume "/mnt/config/$NAME/cfg":/config \
    --volume "/mnt/config/$NAME/web":/config/www \
    --env TZ="Europe/Paris" \
    --env URL="$SWAG_DOMAIN" \
    --env VALIDATION="dns" \
    --env DNSPLUGIN="cloudflare" \
    --env EMAIL="$SWAG_EMAIL" \
    --env CERTPROVIDER="zerossl" \
    --env SUBDOMAINS="wildcard" \
    --env DOCKER_MODS=linuxserver/mods:swag-auto-reload \
    --publish 4443:443 \
    "lscr.io/linuxserver/swag:$VERSION"
}

requirements() {
  mkdir -p "/mnt/config/$NAME"
}
