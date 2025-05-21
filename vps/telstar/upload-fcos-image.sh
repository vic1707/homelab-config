#!/usr/bin/env bash
set -euo pipefail
set -o errtrace
trap 'echo "❌ UNEXPECTED Error occurred on line $LINENO"' ERR

#############################################
# Imported Variables
#############################################
HCLOUD_TOKEN=$(gopass show -o api-token.hetzner key)
export HCLOUD_TOKEN
#############################################
# Configuration Variables
#############################################
ARCH="arm" # Options: arm or x64
NAME="telstar"
SERVER_TYPE="cax11"
SERVER_LOCATION="fsn1" # fsn1 = EU-Central (Germany)

#############################################
# Mode Flags
#############################################
DOWNLOAD_IMAGE=false
UPLOAD_IMAGE=false
CREATE_SERVER=false
CLEANUP=true

#############################################
# Usage Help
#############################################
usage() {
    cat << EOF
	Usage: $(basename "$0") [OPTIONS] <butane-file>

	Options:
	--download-image         Download FCOS Hetzner image
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
        --download-image) DOWNLOAD_IMAGE=true ;;
        --upload-image) UPLOAD_IMAGE=true ;;
        --create-server) CREATE_SERVER=true ;;
        --no-cleanup) CLEANUP=false ;;
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

if ! $DOWNLOAD_IMAGE && ! $UPLOAD_IMAGE && ! $CREATE_SERVER; then
    echo "❌ No action specified. Use --download-image, --upload-image or --create-server." >&2
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
if $DOWNLOAD_IMAGE; then
    TMP_DIR="$(mktemp --directory ./__TMP__Fedora-CoreOS-image-creation.XXXXXX)"

    RAW_IMG_PATH=$(coreos_installer download \
        --stream stable \
        --platform hetzner \
        --format raw.xz \
        --architecture "$IMG_ARCH" \
        --directory "$TMP_DIR")

    echo "✅ Fedora raw.xz downloaded at '$RAW_IMG_PATH'."
fi

#############################################
# Upload Image to Hetzner
#############################################
if $UPLOAD_IMAGE; then
    if [[ -z ${TMP_DIR:-} ]] || [[ ! -f "$RAW_IMG_PATH" ]]; then
        echo "❌ ISO not found. Run with --download-image." >&2
        exit 1
    fi

    if hcloud image list --type snapshot --architecture "$ARCH" --selector "$IMG_TAGS" --output json \
        | jq -e 'length == 1' > /dev/null; then
        echo "✅ Image matching '$IMG_TAGS' already exists on Hetzner."

    else
        echo "🚀 Uploading image to Hetzner..."

        hcloud-upload-image upload \
            --image-path "$RAW_IMG_PATH" \
            --architecture "$ARCH" \
            --compression xz \
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

        echo "$IGNITION_FILE" | hcloud server create \
            --name "$NAME" \
            --type "$SERVER_TYPE" \
            --image "$IMAGE_ID" \
            `# TODO: IP handling sucks` \
            --primary-ipv4 "telstar-v4" \
            --primary-ipv6 "telstar-v6" \
            --location "$SERVER_LOCATION" \
            --label "$IMG_TAGS" \
            --user-data-from-file -

        echo "✅ Server '$NAME' created successfully."
    fi
fi

#############################################
# Cleanup
#############################################
if $CLEANUP && [[ -n ${TMP_DIR:-} ]]; then
    echo "🗑️ Cleaning up temporary files..."
    rm -rf "$TMP_DIR"
    echo "✅ Cleanup done."
fi
