#!/usr/bin/env bash
set -euo pipefail
set -o errtrace
trap 'echo "❌ UNEXPECTED Error occurred on line $LINENO"' ERR

## Script is made for aarch64

#############################################
# Config Variables
#############################################
## VMs
CORE_COUNT=4
RAM_MB=4096
## Hetzner
NAME=telstar
SERVER_TYPE=cax11
SERVER_LOCATION=fsn1 # fsn1 = EU-Central (Germany)

## FCOS
STREAM=stable

## Required variables
[[ -f ".conf/${ENV:?ENV is not set}.gomplate.yaml" ]] || {
    echo "Error: Config file '.conf/${ENV}.gomplate.yaml' does not exist. Check 'ENV' variable" >&2
    exit 1
}

#############################################
# Imported Variables
#############################################
HCLOUD_TOKEN=$(gopass show -o api-token.hetzner key)
export HCLOUD_TOKEN

#############################################
# Utility functions
#############################################
get_fcos_release_infos() {
    local stream="$1" arch="$2" platform="$3" format="$4"
    local -n RET=$5

    local releases release_infos
    releases=$(curl --silent "https://builds.coreos.fedoraproject.org/streams/$stream.json")
    release_infos=$(echo "$releases" | jq -e ".architectures.$arch.artifacts.$platform")

    local release_version release_link
    release_version=$(echo "$release_infos" | jq -r ".release")
    release_link=$(echo "$release_infos" | jq -r ".formats.\"$format\".disk.location")

    # shellcheck disable=SC2034 # variable is used by nameref
    RET=("$release_version" "$release_link")
}

#############################################
# Usage Help
#############################################
usage() {
    cat << EOF
    Usage: $(basename "$0") <butane-file> [command] [command_options]

    Commands:
        help                    Show this help message
        vm                      Starts a local VM
        hetzner                 Manages hetzner resources

    Command Options:
        hetzner:
            --upload-image      Fetches and upload the latest FCOS image (if necessary)
            --create-server     Fetches and upload the latest FCOS image (if necessary)
            --remove-image      Removes existing FCOS image
            --remove-server     Removes existing matching server

    Arguments:
        <butane-file>           Path to the Butane configuration file (required)
EOF
}

#############################################
# Arguments parsing
#############################################
if [[ $# -lt 1 ]]; then
    usage
    exit 1
fi

BUTANE_FILE=$1
[[ ! -f $BUTANE_FILE ]] && echo "❌ Butane file not found." && exit 1
shift

#############################################
# Actual work
#############################################
generate_ignition() {
    echo "⚙️ Generating Ignition file..."
    IGNITION_PATH="$(mktemp)"
    gomplate --config gomplate/config.yaml -f ".conf/$ENV.gomplate.yaml" \
        | butane -d "$(dirname "$BUTANE_FILE")" --output "$IGNITION_PATH" ignition.bu.yml
    IGNITION_HASH=$(md5sum "$IGNITION_PATH" | cut -d' ' -f1)
}

# Accepts port mappings in the format: ["host:guest" "host:guest" ...]
build_hostfwd_args() {
    local hostfwd_opts=()
    for port_pair in "$@"; do
        IFS=":" read -r host_port guest_port <<< "$port_pair"
        hostfwd_opts+=("hostfwd=tcp::${host_port}-:${guest_port}")
    done

    local hostfwd_combined
    hostfwd_combined=$(
        IFS=,
        echo "${hostfwd_opts[*]}"
    )

    echo "-netdev user,id=net0,${hostfwd_combined} -device virtio-net-device,netdev=net0"
}

COMMAND=$1
shift
case "$COMMAND" in
    vm)
        ENABLE_BACKUP=false generate_ignition
        get_fcos_release_infos "$STREAM" aarch64 qemu qcow2.xz QEMU_INFOS
        TMP_DIR="$(mktemp --directory ./__TMP__Fedora-CoreOS-image-creation.XXXXXX)"
        IMG_PATH="$TMP_DIR/fcos.qcow2.xz"

        echo "📦 Downloading FCOS ${QEMU_INFOS[0]}..."
        curl -L "${QEMU_INFOS[1]}" -o "$IMG_PATH"

        echo "⚙️ Uncompressing image file..."
        unxz "$IMG_PATH"

        echo "💻 Starting VM..."

        # Define port mappings
        INTERNAL_SSH_PORT=$(gopass show -o telstar/ssh-port)
        HOSTFWD_ARGS=$(build_hostfwd_args "2222:$INTERNAL_SSH_PORT" "4443:443")

        # shellcheck disable=SC2086 # $HOSTFWD_ARGS not in quotes
        qemu-system-aarch64 \
            -machine virt -cpu cortex-a72 \
            -smp $CORE_COUNT -m $RAM_MB \
            -nographic \
            -bios /opt/homebrew/share/qemu/edk2-aarch64-code.fd \
            -fw_cfg name=opt/com.coreos/config,file="$IGNITION_PATH" \
            -drive if=virtio,file="${IMG_PATH%%.xz}",format=qcow2,media=disk \
            $HOSTFWD_ARGS \
            -serial mon:stdio

        ;;
    hetzner)
        ENABLE_BACKUP=true generate_ignition
        get_fcos_release_infos "$STREAM" aarch64 hetzner raw.xz HETZNER_INFOS
        IMG_TAGS="version=${HETZNER_INFOS[0]},stream=$STREAM"
        SERVER_TAGS="os=fedora-coreos,$IMG_TAGS,name=$NAME,ignition_hash=$IGNITION_HASH"

        while [[ $# -gt 0 ]]; do
            case "$1" in
                --upload-image)
                    if hcloud image list --type snapshot --architecture arm --selector "$IMG_TAGS" --output json \
                        | jq -e 'length == 1' > /dev/null; then
                        echo "✅ Image matching '$IMG_TAGS' already exists on Hetzner."
                    else
                        echo "🚀 Uploading image to Hetzner..."

                        hcloud-upload-image upload \
                            --image-url "${HETZNER_INFOS[1]}" \
                            --architecture arm \
                            --compression xz \
                            --description "Fedora CoreOS v${HETZNER_INFOS[0]}" \
                            --labels "$IMG_TAGS"

                        echo "✅ Image uploaded successfully."
                        hcloud-upload-image cleanup
                    fi
                    ;;
                --create-server)
                    if hcloud server list --selector "$SERVER_TAGS" --output json | jq -e 'length == 1' > /dev/null; then
                        echo "✅ Server already exists."
                    else
                        IMAGE_ID="$(hcloud image list --type snapshot --architecture arm --selector "$IMG_TAGS" --output json | jq -re '.[0].id' 2> /dev/null || true)"
                        if [[ -z $IMAGE_ID || $IMAGE_ID == "null" ]]; then
                            echo "❌ No matching image found on Hetzner! Run with --upload-image first." >&2
                            exit 1
                        fi
                        echo "✅ Image ID found: '$IMAGE_ID'"

                        hcloud server create \
                            --name "$NAME" \
                            --type "$SERVER_TYPE" \
                            --image "$IMAGE_ID" \
                            `# TODO: IP handling sucks` \
                            --primary-ipv4 "telstar-v4" \
                            --primary-ipv6 "telstar-v6" \
                            --location "$SERVER_LOCATION" \
                            --label "$SERVER_TAGS" \
                            --user-data-from-file "$IGNITION_PATH"
                    fi
                    ;;
                --remove-image)
                    IMAGE_ID="$(hcloud image list --type snapshot --architecture arm --selector "$IMG_TAGS" --output json | jq -re '.[0].id' 2> /dev/null || true)"
                    if ! [[ -z $IMAGE_ID || $IMAGE_ID == "null" ]]; then
                        hcloud image delete "$IMAGE_ID"
                        echo "✅ Image $IMAGE_ID successfully deleted"
                    else
                        echo "✅ No Image to remove"
                    fi
                    ;;
                --remove-server)
                    ## We omit the hash when trying to remove the server as we probably want to update the conf
                    SERVER_ID="$(hcloud server list --selector "${SERVER_TAGS%%,ignition_hash=*}" --output json | jq -re '.[0].id' 2> /dev/null || true)"
                    if ! [[ -z $SERVER_ID || $SERVER_ID == "null" ]]; then
                        hcloud server delete "$SERVER_ID"
                        echo "✅ Server $SERVER_ID successfully deleted"
                    else
                        echo "✅ No Server to remove"
                    fi
                    ;;
                *)
                    usage
                    exit 1
                    ;;
            esac
            shift
        done
        ;;
    help | *)
        usage
        exit 1
        ;;
esac

echo "🗑️ Cleaning up temporary files..."
rm -rf "${TMP_DIR:-}" "$IGNITION_PATH"
echo "✅ Cleanup done."
