#!/usr/bin/env bash
set -euo pipefail
set -o errtrace
trap 'echo "❌ Error occurred on line $LINENO"' ERR

#############################################
# Imported Variables
#############################################
HCLOUD_TOKEN=$(gopass show -o hetzner/homelab/rw-api-token)
export HCLOUD_TOKEN
#############################################
# Configuration Variables
#############################################
ARCH="arm" # Options: arm or x64
NAME="telstar"
IMAGE_NAME="fcos-${NAME}"
SERVER_TYPE="cax11"
SERVER_LOCATION="fsn1" # fsn1 = EU-Central (Germany)

#############################################
# Mode Flags
#############################################
EMBED_ISO=false
UPLOAD_IMAGE=false
CREATE_SERVER=false
CLEANUP=true
BOOT_VM=false
BOOT_VM_PATH=""

#############################################
# Usage Help
#############################################
usage() {
    cat << EOF
	Usage: $(basename "$0") [OPTIONS] <butane-file>

	Options:
    --boot-vm [iso]          Boot a VM using the generated ISO or a provided one (arm64 QEMU)
	--embed-iso              Generate the embedded ISO only
	--upload-image           Upload the embedded ISO to Hetzner
	--create-server          Create a server from the uploaded image
	--no-cleanup             Do not delete temporary ISO after upload
	-h, --help               Show this help message and exit

	Arguments:
	<butane-file>            Path to the Butane configuration file (required)

	Notes:
	- You must specify at least one action.
	- Actions are performed sequentially: embed → upload → create.
EOF
}

#############################################
# Argument Parsing
#############################################
if [[ $# -lt 1 ]]; then
    usage
    exit 1
fi

BUTANE_FILE=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --embed-iso) EMBED_ISO=true ;;
        --upload-image) UPLOAD_IMAGE=true ;;
        --create-server) CREATE_SERVER=true ;;
        --no-cleanup) CLEANUP=false ;;
        --boot-vm)
            BOOT_VM=true
            if [[ $# -gt 1 && ! "$2" =~ ^--.* ]]; then
                shift
                BOOT_VM_PATH="$1"
            fi
            ;;
        -h | --help)
            usage
            exit 0
            ;;
        -*)
            echo "❌ Unknown option: $1" >&2
            usage
            exit 1
            ;;
        *)
            if [[ -z $BUTANE_FILE ]]; then
                BUTANE_FILE="$1"
            else
                echo "❌ Unexpected argument: $1" >&2
                usage
                exit 1
            fi
            ;;
    esac
    shift
done

if [[ ! -f $BUTANE_FILE ]]; then
    echo "❌ Error: Butane file '$BUTANE_FILE' not found." >&2
    exit 1
fi

if ! $EMBED_ISO && ! $UPLOAD_IMAGE && ! $CREATE_SERVER; then
    echo "❌ No action specified. Use --embed-iso, --upload-image, or --create-server." >&2
    usage
    exit 1
fi

#############################################
# Helper: coreos-installer Wrapper
# TODO: replace with mise install once supported on macOS
# See: <https://github.com/coreos/coreos-installer/issues/1191>
#############################################
COREOS_IMAGE="quay.io/coreos/coreos-installer:release"
coreos_installer() {
    podman run --rm --interactive \
        --volume "${PWD}":/pwd --workdir /pwd \
        "$COREOS_IMAGE" "$@"
}

#############################################
# Pull/Update CoreOS Installer Image
#############################################
echo "🔍 Checking coreos-installer image..."
if ! podman image exists "$COREOS_IMAGE" || ! (
    LOCAL_SHA=$(podman image inspect "$COREOS_IMAGE" --format '{{.Digest}}' 2> /dev/null || echo "")
    podman manifest inspect "$COREOS_IMAGE" \
        | jq -e --arg sha "$LOCAL_SHA" '.manifests[] | select(.digest == $sha)' > /dev/null
); then
    echo "📦 Pulling latest coreos-installer..."
    podman pull "$COREOS_IMAGE" > /dev/null
else
    echo "✅ coreos-installer is up-to-date."
fi

#############################################
# Computed variables
#############################################
IGNITION_FILE=$(gomplate -f "$BUTANE_FILE" --plugin gopass=gopass | butane --files-dir "$(dirname "$BUTANE_FILE")")
IGNITION_HASH=$(echo "$IGNITION_FILE" | md5sum | cut -d' ' -f1)
IMG_TAGS="os=fedora-coreos,name=$NAME,ignition_hash=$IGNITION_HASH"
case "$ARCH" in
    arm) IMG_ARCH="aarch64" ;;
    x64) IMG_ARCH="x86_64" ;;
    *)
        echo "❌ Invalid arch: $ARCH" >&2
        exit 1
        ;;
esac

#############################################
# Embed Ignition Config into ISO
#############################################
if $EMBED_ISO; then
    echo "🧬 Embedding Ignition config..."

    TMP_DIR="$(mktemp --directory ./__TMP__Fedora-CoreOS-image-creation.XXXXXX)"

    RAW_IMG_PATH=$(coreos_installer download \
        --stream stable \
        --platform metal \
        --format iso \
        --architecture "$IMG_ARCH" \
        --decompress \
        --directory "$TMP_DIR")

    echo "$IGNITION_FILE" | coreos_installer iso ignition embed \
        --output "$TMP_DIR/$IMAGE_NAME.iso" \
        "$RAW_IMG_PATH"

    echo "✅ Embedded ISO created at '$TMP_DIR/$IMAGE_NAME.iso'."
fi

#############################################
# Upload Image to Hetzner
#############################################
if $UPLOAD_IMAGE; then
    if [[ -z ${TMP_DIR:-} ]] || [[ ! -f "$TMP_DIR/$IMAGE_NAME.iso" ]]; then
        echo "❌ ISO not found. Run with --embed-iso." >&2
        exit 1
    fi

    if hcloud image list --type snapshot --architecture "$ARCH" --selector "$IMG_TAGS" --output json \
        | jq -e 'length == 1' > /dev/null; then
        echo "✅ Image matching '$IMG_TAGS' already exists on Hetzner."

    else
        echo "🚀 Uploading image to Hetzner..."

        hcloud-upload-image upload \
            --image-path "$TMP_DIR/$IMAGE_NAME.iso" \
            --architecture "$ARCH" \
            --description "Fedora CoreOS custom image for $NAME" \
            --labels "$IMG_TAGS"

        echo "✅ Image uploaded successfully."

        hcloud-upload-image cleanup
    fi
fi

#############################################
# Create Server
#############################################
if $CREATE_SERVER; then
    echo "🔍 Searching for uploaded image..."

    IMAGE_ID="$(hcloud image list --type snapshot --architecture "$ARCH" --selector "$IMG_TAGS" --output json | jq -re '.[0].id' 2> /dev/null || true)"
	if [[ -z "$IMAGE_ID" || "$IMAGE_ID" == "null" ]]; then
        echo "❌ No matching image found on Hetzner! Run with --upload-image." >&2
        exit 1
    fi
    echo "✅ Image ID found: '$IMAGE_ID'"

    if hcloud server list --selector "$IMG_TAGS" --output json | jq -e 'length == 1' > /dev/null; then
        echo "✅ Server already exists with image."
    else
        echo "🚀 Creating server '$NAME'..."

        hcloud server create \
            --name "$NAME" \
            --type "$SERVER_TYPE" \
            --image "$IMAGE_ID" \
            --location "$SERVER_LOCATION" \
            --label "$IMG_TAGS"

        echo "✅ Server '$NAME' created successfully."
    fi
fi

#############################################
# Boot VM from ISO (Generated or Provided)
#############################################
if $BOOT_VM; then
    ISO_PATH="${BOOT_VM_PATH:-$TMP_DIR/$IMAGE_NAME.iso}"
    if [[ ! -f "$ISO_PATH" ]]; then
        echo -e "❌ ISO not found at '$ISO_PATH'. Use --embed-iso or provide a path with --boot-vm <path>" >&2
        exit 1
    fi

    echo -e "🚀 Booting Fedora CoreOS ISO in QEMU..."

    qemu-system-aarch64 \
        -machine virt,highmem=off \
        -cpu cortex-a72 \
        -smp 2 \
        -m 2048 \
        -nographic \
        -bios /opt/homebrew/share/qemu/edk2-aarch64-code.fd \
        -drive if=virtio,file="$ISO_PATH",media=cdrom \
        -netdev user,id=net0,hostfwd=tcp::2222-:"${SSH_PORT}" \
        -device virtio-net-device,netdev=net0 \
        -serial mon:stdio
fi

#############################################
# Cleanup
#############################################
if $CLEANUP && [[ -n ${TMP_DIR:-} ]]; then
    echo "🗑️ Cleaning up temporary files..."
    rm -rf "$TMP_DIR"
    echo "✅ Cleanup done."
fi
