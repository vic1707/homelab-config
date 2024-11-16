#!/bin/bash

# check if repo is up to date, if not error and ask to pull
if git fetch && git status -uno | grep 'behind'; then
    echo "Error updating repo. Please pull manually."
    exit 1
fi

# if podman-restart.service is disabled we enable it
loginctl enable-linger "$USER"
if ! systemctl --user is-enabled podman-restart.service > /dev/null; then
    echo "Enabling podman-restart.service"
    systemctl --user enable podman-restart.service
    systemctl --user start podman-restart.service
fi

########################################
####       Utilities functions      ####
########################################
exit_on_error() {
    echo "Error: $1" >&2
    exit 1
}
root_forbidden() {
    [ "$(id -u)" -eq 0 ] && exit_on_error "This script must NOT be run as root. Try 'sudo $0'"
}
sudoer_required() {
    if ! sudo -n true 2> /dev/null; then
        exit_on_error "This script must be able to call 'sudo'."
    fi
}
check_env_vars() {
    for var in "$@"; do
        [ -n "${!var}" ] || exit_on_error "Environment variable $var is not set or empty."
    done
}
########################################
####    Setup & checks functions    ####
########################################
NFS_OPTIONS="ro,acl,hard,noatime,nodev,nodiratime,noexec,nosuid,vers=4,minorversion=1"
jellyfin_setup() {
    RELOAD_FSTAB=0
    ## Check required NFS mounts ##
    local SHARES=("Animes" "Movies" "Music" "NSFW" "Scans" "Shows")
    for share in "${SHARES[@]}"; do
        local mount_point="/media/jellyfin/$share"

        if ! grep -q "$mount_point" /etc/fstab; then
            RELOAD_FSTAB=1
            echo "Adding $share volume to fstab..."
            sudo mkdir -p "$mount_point"
            echo "10.0.0.2:/mnt/Bhulk/Medias/$share $mount_point nfs $NFS_OPTIONS 0 0" | sudo tee -a /etc/fstab
        fi
    done
    if [ "$RELOAD_FSTAB" -eq 1 ]; then
        echo "Reloading fstab..."
        sudo mount -a
        sudo systemctl daemon-reload
    fi

    for share in "${SHARES[@]}"; do
        local mount_point="/media/jellyfin/$share"

        findmnt "$mount_point" > /dev/null || exit_on_error "[$share] isn't correctly mounted at $mount_point."
    done
}
wireguard_setup() {
    # https://github.com/wg-easy/wg-easy/wiki/Using-WireGuard-Easy-with-Podman#loading-kernel-modules
    modules=("ip_tables" "iptable_filter" "iptable_nat" "wireguard" "xt_MASQUERADE")
    autoload_file="/etc/modules-load.d/wireguard.conf"
    sudo touch $autoload_file

    for module in "${modules[@]}"; do
        if ! lsmod | grep -q "^${module}"; then
            echo "${module} not loaded. Loading now..."
            sudo modprobe "$module"
            if ! grep -q "^${module}" "$autoload_file"; then
                echo "$module" | sudo tee -a "$autoload_file" > /dev/null
            fi
        fi
    done
}
########################################

root_forbidden
sudoer_required

# shellcheck disable=SC1091
source .env

# Default services if no specific services are provided
mapfile -t DEFAULT_SERVICES < <(podman run --rm -i docker.io/mikefarah/yq '.services | to_entries | .[] | .key' < compose.yml)

echo "AVAILABLE SERVICES: ${DEFAULT_SERVICES[*]}"

# Copy all arguments passed
args=("$@")

# Check if the first argument is not 'up', pass all arguments to `podman compose` and exit
if [ "$1" != "up" ]; then
    podman compose "${args[@]}"
    exit $?
fi

# Remove 'up' from the arguments
shift

services=()
# Iterate through the remaining arguments
while [ "$#" -gt 0 ]; do
    case "$1" in
        -f | --file | -t | --timeout | --scale | --exit-code-from | --build-arg) # Options taking a value
            shift 2
            ;;
        -*) # Flags
            shift
            ;;
        *) # Assume it's a service name
            services+=("$1")
            shift
            ;;
    esac
done

# If no specific services are provided, default to all services
if [ ${#services[@]} -eq 0 ]; then
    services=("${DEFAULT_SERVICES[@]}")
fi

echo "Checking requirements for ${services[*]}"

# Check conditions for given services
for service in "${services[@]}"; do
    case "$service" in
        jellyfin)
            maybe_error_msg=$(jellyfin_setup)
            # shellcheck disable=SC2181
            if [ "$?" -ne 0 ]; then
                exit_on_error "Jellyfin checks didn't pass: $maybe_error_msg"
            fi
            ### Check that containers can access devices
            if getsebool container_use_devices | grep -q 'off'; then
                sudo setsebool -P container_use_devices=1
                echo "container_use_devices set to 1 (on)"
            fi
            ;;
        caddy)
            check_env_vars DOMAIN ZEROSSL_EMAIL
            ;;
        wireguard)
            check_env_vars DOMAIN WGUI_PASSWORD_HASH
            wireguard_setup
            ;;
        authelia)
            check_env_vars DOMAIN
            ;;
        gickup | gluetun | transmission | homepage | myspeed | myspeed_gluetun)
            echo "No checks required for $service."
            ;;
        *)
            exit_on_error "Unregistered service: $service."
            ;;
    esac
    echo "$service OK."
done

podman compose "${args[@]}"
exit $?
