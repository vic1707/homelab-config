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
copy_files_with_check() {
    declare -n pairs="$1"

    for src in "${!pairs[@]}"; do
        dest_dir="${pairs[$src]}"

        [[ -f $src ]] || exit_on_error "Source file does not exist: $src"
        mkdir -p "$dest_dir" || exit_on_error "Failed to create destination directory: $dest_dir"
        cp "$src" "$dest_dir" || exit_on_error "Failed to copy $src to $dest_dir"
    done
}
########################################
####    Setup & checks functions    ####
########################################
NFS_OPTIONS="ro,acl,hard,noatime,nodev,nodiratime,noexec,nosuid,vers=4,minorversion=1"
jellyfin_setup() {
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
    touch $autoload_file

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

# ensure secrets have the right permissions
sudo chown marina:marina -R secrets/
chmod 700 -R secrets/

# Default services if no specific services are provided
mapfile -t DEFAULT_SERVICES < <(podman run --rm -i docker.io/mikefarah/yq '.services | to_entries | .[] | .key' < docker-compose.yml)

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
            echo "Jellyfin OK."
            ;;
        gickup)
            declare -A files=(
                ["$PWD/gickup/conf.yml"]="/mnt/config/gickup"
            )
            copy_files_with_check files
            echo "Gickup OK."
            ;;
        transmission)
            check_env_vars OVPN_CONFIG OVPN_PROVIDER
            declare -A files=(
                ["$PWD/transmission/keep_torrent_file.sh"]="/mnt/config/transmission"
            )
            copy_files_with_check files
            echo "Transmission OK."
            ;;
        caddy)
            check_env_vars DOMAIN ZEROSSL_EMAIL
            declare -A files=(
                ["$PWD/caddy/Caddyfile"]="/mnt/config/caddy"
            )
            copy_files_with_check files
            echo "Caddy OK."
            ;;
        wireguard)
            check_env_vars DOMAIN WGUI_PASSWORD_HASH
            wireguard_setup
            echo "Wireguard OK."
            ;;
        *)
            rmdir "/mnt/config/$service" 2> /dev/null
            rmdir "/mnt/data/$service" 2> /dev/null
            exit_on_error "Unregistered service: $service."
            ;;
    esac
done

podman compose "${args[@]}"
exit $?
