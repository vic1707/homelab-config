#!/bin/bash

# Check for NON root privileges
if [ "$(id -u)" -eq 0 ]; then
    echo "This script must NOT be run as root. Please use a regular user."
    exit 1
fi

### STATIC VARIABLES ###
POD_PWD="$(dirname "${BASH_SOURCE[0]}")"
NAME=wireguard
VERSION=9
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
    ## 1. WG_HOST                             ##
    ## 2. WG_PASSWORD                         ##
    ############################################
    if [ -z "$WG_HOST" ]; then
        echo "WG_HOST is not set. Please set it."
        exit 1
    fi
    if [ -z "$WG_PASSWORD" ]; then
        echo "WG_PASSWORD is not set. Please set it."
        exit 1
    fi

    ######## Check for global variables ########
    ## 1. FEDEX_IP                            ##
    ############################################
    if [ -z "$FEDEX_IP" ]; then
        echo "FEDEX_IP is not set. Please set it."
        exit 1
    fi

    return 0
}

start() {
    podman run \
        --detach \
        --name "$NAME" \
        --network shared \
        `# Wireguard port` \
        --publish 51820:51820/udp \
        `# Wireguard UI port` \
        `# --publish 51821:51821/tcp` \
        --volume "/mnt/config/$NAME/":/etc/wireguard \
        --sysctl net.ipv6.conf.all.disable_ipv6=1 \
        --sysctl net.ipv4.conf.all.src_valid_mark=1 \
        --sysctl net.ipv4.ip_forward=1 \
        --env TZ="Europe/Paris" \
        --env WG_HOST="$WG_HOST" \
        --env PASSWORD="$WG_PASSWORD" \
        --env WG_DEFAULT_DNS="$FEDEX_IP" \
        --cap-add=NET_ADMIN \
        --cap-add=SYS_MODULE \
        --cap-add=NET_RAW \
        ghcr.io/wg-easy/wg-easy:$VERSION
}

requirements() {
    ## Put setup lines here, like NFS mounts, etc.
    mkdir -p "/mnt/bhulk/$NAME"
    mkdir -p "/mnt/config/$NAME"
}
