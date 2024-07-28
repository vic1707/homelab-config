#!/bin/bash

# Check for NON root privileges
if [ "$(id -u)" -eq 0 ]; then
    echo "This script must NOT be run as root. Please use a regular user."
    exit 1
fi

### STATIC VARIABLES ###
POD_PWD="$(dirname "${BASH_SOURCE[0]}")"
NAME=caddy
VERSION=2.8.4-alpine
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
    ## 1. DOMAIN                              ##
    ## 2. ZEROSSL_EMAIL                       ##
    ############################################
    if [ -z "$DOMAIN" ]; then
        echo "DOMAIN is not set. Please set it."
        exit 1
    fi
    if [ -z "$ZEROSSL_EMAIL" ]; then
        echo "ZEROSSL_EMAIL is not set. Please set it."
        exit 1
    fi

    return 0
}

start() {
    podman run \
        --detach \
        --network shared \
        --name "$NAME" \
        --publish 8080:80/tcp \
        --publish 4443:443/tcp \
        `# env config`\
        --env DOMAIN="$DOMAIN" \
        --env ZEROSSL_EMAIL="$ZEROSSL_EMAIL" \
        `# don't know why Caddy requires the 'z' flag on volumes` \
        --volume "/mnt/config/$NAME/Caddyfile":/etc/caddy/Caddyfile:z,ro \
        --volume "/mnt/config/$NAME/data":/data:z,rw \
        --volume "/mnt/config/$NAME/site":/usr/share/caddy:z,ro \
        --env TZ="Europe/Paris" \
        "docker.io/library/caddy:$VERSION"
    return $?
}

requirements() {
    ## Put setup lines here, like NFS mounts, etc.
    mkdir -p "/mnt/config/$NAME/config"
    mkdir -p "/mnt/config/$NAME/data"
    mkdir -p "/mnt/config/$NAME/site"
    ## override some config files
    cp "$POD_PWD/Caddyfile" "/mnt/config/$NAME/Caddyfile"
    cp "$POD_PWD/index.html" "/mnt/config/$NAME/site/index.html"
}
