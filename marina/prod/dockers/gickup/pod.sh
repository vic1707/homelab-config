#!/bin/bash

# Check for NON root privileges
if [ "$(id -u)" -eq 0 ]; then
    echo "This script must NOT be run as root. Please use a regular user."
    exit 1
fi

### STATIC VARIABLES ###
POD_PWD="$(dirname "${BASH_SOURCE[0]}")"
NAME=gickup
VERSION=0.10.30
# shellcheck disable=SC2034
RESTART_POLICY=on-failure # no | always | on-success | on-failure | on-abnormal | on-abort | on-watchdog
########################

source_env() {
    ## Nothing to do here
    true;
}

start() {
    podman run \
        --detach \
        --network shared \
        --ip="$GICKUP_IP" \
        --name "$NAME" \
        --volume "/mnt/bhulk/$NAME/":/data:rw \
        --volume "/mnt/config/$NAME":/config:ro \
        --env TZ="Europe/Paris" \
        "buddyspencer/gickup:$VERSION" "/config/conf.yml"
}

requirements() {
    ## Put setup lines here, like NFS mounts, etc.
    mkdir -p "/mnt/bhulk/$NAME"
    mkdir -p "/mnt/config/$NAME"
    ## Gickup config
    cp "$POD_PWD/conf.yml" "/mnt/config/$NAME/conf.yml"
    if [ ! -f "$POD_PWD/token" ]; then
        echo "Token file not found."
        exit 1
    fi
    cp "$POD_PWD/token" "/mnt/config/$NAME/token"
}
