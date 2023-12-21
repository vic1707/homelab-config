#!/bin/bash

# Check for NON root privileges
if [ "$(id -u)" -eq 0 ]; then
    echo "This script must NOT be run as root. Please use a regular user."
    exit 1
fi

### STATIC VARIABLES ###
POD_PWD="$(dirname "${BASH_SOURCE[0]}")"
NAME=
VERSION=
# shellcheck disable=SC2034
RESTART_POLICY= # no | always | on-success | on-failure | on-abnormal | on-abort | on-watchdog
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
    ## 1. ...                                 ##
    ############################################
    return 0
}

start() {
    # ...
    podman run \
        --detach \
        --name "$NAME" \
        --env TZ="Europe/Paris" \
        "container:$VERSION"
}

requirements() {
    ## Put setup lines here, like NFS mounts, etc.
    true;
}
