#!/usr/bin/env bash
set -euo pipefail

## 🧾 Usage check
if [[ $# -lt 1 ]] || [[ ! -f $1 ]]; then
    echo "❌ Usage: $0 <butane-file>"
    echo "<butane-file> must be a valid path"
    exit 1
fi
BUTANE_FILE="$1"

## 🛠️ coreos-installer wrapper (tool cannot be installed on macOS)
## https://github.com/coreos/coreos-installer/issues/1191
COREOS_IMAGE="quay.io/coreos/coreos-installer:release"
coreos_installer() {
    podman run --rm --interactive \
        --volume "${PWD}":/pwd --workdir /pwd \
        "$COREOS_IMAGE" "$@"
}

## 🛡️ HCLOUD Auth
HCLOUD_TOKEN=$(gopass show -o hetzner/homelab/rw-api-token)
export HCLOUD_TOKEN
## 🧱 VPS Settings
ARCH=arm # or x64
NAME="telstar"
IMAGE_NAME="fcos-${NAME}"
BUTANE_HASH=$(md5sum "$BUTANE_FILE" | cut -d' ' -f1)
IMG_TAGS="os=fedora-coreos,name=$NAME,butane_hash=$BUTANE_HASH"

case "$ARCH" in
    arm) IMG_ARCH="aarch64" ;;
    x64) IMG_ARCH="x86_64" ;;
    *)
        echo "❌ Invalid arch: $ARCH" >&2
        exit 1
        ;;
esac

echo "🔍 Checking if coreos-installer image is up-to-date..."
## If local image then we compare with remote version
if ! podman image exists "$COREOS_IMAGE" \
    || ! (
        LOCAL_SHA=$(podman image inspect "$COREOS_IMAGE" --format '{{.Digest}}' 2> /dev/null)
        podman manifest inspect "$COREOS_IMAGE" \
            | jq -e --arg sha "$LOCAL_SHA" '.manifests[] | select(.digest == $sha)' > /dev/null
    ); then
    echo "📦 Remote image has changed or local missing. Pulling latest..."
    podman pull "$COREOS_IMAGE" > /dev/null 2>&1
else
    echo "✅ Local coreos-installer image is up-to-date."
fi

echo "🔍 Looking for images on Hetzner"
if hcloud image list --type snapshot --architecture "$ARCH" --selector "$IMG_TAGS" --output json \
    | jq -e 'length == 1' > /dev/null; then
    echo "✅ Image matching '$IMG_TAGS' already exists on Hetzner."
else
    echo "❌ No matching image found. Proceeding with creation..."

    echo "⬇️  Downloading Fedora CoreOS raw image..."
    RAW_IMG_PATH=$(coreos_installer download \
        --stream stable \
        --platform metal \
        --format iso \
        --architecture "$IMG_ARCH" \
        --decompress)

    echo "🧬 Embedding Ignition config into image..."
    butane \
        --files-dir "$PWD" \
        "$BUTANE_FILE" \
        | coreos_installer iso ignition embed \
            --output "$IMAGE_NAME.iso" \
            "$RAW_IMG_PATH"

    ## ☁️ Upload to Hetzner
    echo "🚀 Uploading image to Hetzner Cloud..."
    hcloud-upload-image upload \
        --image-path "$IMAGE_NAME.iso" \
        --architecture "$ARCH" \
        --description "Fedora CoreOS custom image for $NAME" \
        --labels "$IMG_TAGS"

    echo "🗑️ Cleaning up remains of image upload"
    hcloud-upload-image cleanup

    echo "✅ Upload complete."
fi

# Server config
IMAGE_ID="$(hcloud image list --type snapshot --architecture "$ARCH" --selector "$IMG_TAGS" --output json | jq -e '.[0].id')"
SERVER_NAME="$NAME"
SERVER_TYPE="cax11"
SERVER_LOCATION="fsn1" # fsn1 = EU-Central (Germany)

if hcloud server list --selector "$IMG_TAGS" --output json \
    | jq -e 'length == 1' > /dev/null; then
    echo "✅ Server '$SERVER_NAME' already exists on Hetzner."
    exit 0
fi

echo "🚀 Creating VPS '$SERVER_NAME' with image ID '$IMAGE_ID'..."

hcloud server create \
    --name "$SERVER_NAME" \
    --type "$SERVER_TYPE" \
    --image "$IMAGE_ID" \
    --location "$SERVER_LOCATION" \
    --label "$IMG_TAGS"

echo "✅ VPS '$SERVER_NAME' created successfully."
