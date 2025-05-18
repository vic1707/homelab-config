#!/usr/bin/env bash
set -euo pipefail
set -o errtrace
trap 'echo "❌ UNEXPECTED Error occurred on line $LINENO"' ERR

#############################################
# Configuration Variables
#############################################
ARCH="arm" # Options: arm or x64

#############################################
# Argument Parsing
#############################################
if [[ $# -lt 1 ]]; then
    usage
    exit 1
fi

BUTANE_FILE="$1"
if [[ ! -f $BUTANE_FILE ]]; then
    echo "❌ Error: Butane file '$BUTANE_FILE' not found." >&2
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
case "$ARCH" in
    arm) IMG_ARCH="aarch64" ;;
    x64) IMG_ARCH="x86_64" ;;
    *)
        echo "❌ Invalid arch: $ARCH" >&2
        exit 1
        ;;
esac


echo "🧬 Save ignition file locally"
IGNITION_PATH="$(mktemp)"
gomplate -f "$BUTANE_FILE" --plugin gopass=gopass | butane --files-dir "$(dirname "$BUTANE_FILE")" --output "$IGNITION_PATH"

echo "🔽 Downloading FCOS hetzner image..."

TMP_DIR="$(mktemp --directory ./__TMP__Fedora-CoreOS-image-creation.XXXXXX)"

RAW_IMG_PATH=$(coreos_installer download \
    --stream stable \
    --platform qemu \
    --format qcow2.xz \
    --decompress \
    --architecture "$IMG_ARCH" \
    --directory "$TMP_DIR")

echo "✅ FCOS image downloaded created at '$RAW_IMG_PATH'."

## If necessary
# qemu-img resize "$RAW_IMG_PATH" 20G

echo "🚀 Booting Fedora CoreOS in QEMU..."

qemu-system-aarch64 \
    -machine virt,highmem=off \
    -cpu cortex-a72 \
    -smp 2 \
    -m 2048 \
    -nographic \
    -bios /opt/homebrew/share/qemu/edk2-aarch64-code.fd \
    -fw_cfg name=opt/com.coreos/config,file="${IGNITION_PATH}" \
    -drive if=virtio,file="$RAW_IMG_PATH",format=qcow2,media=disk \
    -netdev user,id=net0,hostfwd=tcp::2222-:"$(gopass show -o telstar/ssh-port || true)",hostfwd=tcp::8080-:80,hostfwd=tcp::4443-:443 \
    -device virtio-net-device,netdev=net0 \
    -serial mon:stdio
