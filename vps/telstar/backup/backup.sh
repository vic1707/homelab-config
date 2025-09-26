#!/usr/bin/env bash
# shellcheck disable=SC2094 # we read the conf file twice
set -euo pipefail

STATE_DIR="/var/state/"
LOG="/var/log/sync-to-storagebox.log"

CONF="$1"
DEST="$2"

to_seconds() {
    local input=$1
    local num unit
    num=$(echo "$input" | grep -oE '^[0-9]+')
    unit=$(echo "$input" | grep -oE '[a-zA-Z]+$')

    case $unit in
        s | sec | secs | second | seconds) factor=1 ;;
        m | min | mins | minute | minutes) factor=60 ;;
        h | hr | hrs | hour | hours) factor=3600 ;;
        d | day | days) factor=86400 ;;
        w | week | weeks) factor=604800 ;;
        mo | month | months) factor=2592000 ;; # approx 30 days
        y | yr | yrs | year | years) factor=31536000 ;;
        *)
            echo "Unknown unit: $unit" >&2
            return 1
            ;;
    esac

    echo $((num * factor))
}

mkdir -p "$STATE_DIR"
now=$(date +%s)

while read -r path interval; do
    [[ -z $path || $path =~ ^# ]] && continue

    state_key=$(echo "$path" | tr '/ *' '_')
    stamp_file="$STATE_DIR/$state_key.last"

    timeout=$(to_seconds "$interval")

    time_last_run=0
    [[ -f $stamp_file ]] && time_last_run=$(cat "$stamp_file")

    ((now - time_last_run < timeout)) && continue

    exclude=()
    # path is a glob # we exclude matching paths (precedence handling)
    if [[ $path == */\* ]]; then
        path="${path%/*}"
        while read -r cpath _; do
            [[ $cpath == "$path" ]] && continue
            exclude+=("--exclude=$(basename "$cpath")")
        done < <(grep -F "$path/" "$CONF")
    fi

    /usr/bin/rsync --verbose \
        --archive --recursive \
        --delete \
        --fake-super \
        --log-file="$LOG" \
        "${exclude[@]}" \
        "$path/" "$DEST"

    echo "$now" > "$stamp_file"
done < "$CONF"
