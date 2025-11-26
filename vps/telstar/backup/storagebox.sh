#!/usr/bin/env bash
# shellcheck disable=SC2094 # we read the conf file twice
set -euo pipefail

STATE_DIR="/var/state/"
LOG="/var/log/sync-to-storagebox.log"

MODE="$1" # backup/restore
CONF="$2"
STORAGEBOX_ROOT="$3"

log () {
    echo "$1"
    echo "$1" >> "$LOG"
}

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
        mo | month | months) factor=2592000 ;; # ~30 days
        y | yr | yrs | year | years) factor=31536000 ;;
        *)
            log "Unknown unit: $unit"
            return 1
            ;;
    esac

    echo $((num * factor))
}

backup() {
    local path="$1" interval="$2"
    shift 2
    local excludes=("$@")

    ## Handle state
    mkdir -p "$STATE_DIR"
    now=$(date +%s)
    state_key=$(echo "$path" | tr '/ *' '_')
    stamp_file="$STATE_DIR/$state_key.last"

    timeout=$(to_seconds "$interval")
    time_last_run=0
    [[ -f $stamp_file ]] && time_last_run=$(cat "$stamp_file")
    ((now - time_last_run < timeout)) && return

    ## Backup
    log "[$(date)] - Backing up $path (interval: $interval) - Excluded: [${excludes[*]}]"
    /usr/bin/rsync --verbose \
        --archive --recursive \
        --delete \
        --fake-super \
        --relative \
        --log-file="$LOG" \
        "${excludes[@]}" \
        "$path" "$STORAGEBOX_ROOT"

    echo "$now" > "$stamp_file"
}

restore() {
    local path="$1"
    shift
    local excludes=("$@")

    if [[ ${path:0:1} != "/" ]]; then
        log "[WARN] Ignoring non-absolute path: '$path'"
        return
    fi

    SOURCE="${STORAGEBOX_ROOT}${path}"
    if [[ ! -e $SOURCE ]]; then
        log "[WARN] Skipping '$path' – not present in backup."
        return
    fi

    log "[INFO] Restoring: $path"
    /usr/bin/rsync --verbose \
        --archive --recursive \
        `# --delete # deletes empty folders` \
        --fake-super -M--super \
        --log-file="$LOG" \
        "${excludes[@]}" \
        "$SOURCE" "$path"
}

log "[INFO] Starting $MODE script..."

while read -r path interval; do
    [[ -z $path || $path =~ ^# ]] && continue

    exclude=()
    # path is a glob # we exclude matching paths (precedence handling)
    if [[ $path == */\* ]]; then
        # needs to remove the pattern for rsync
        path="${path%/*}"
        while read -r cpath _; do
            [[ $cpath == "$path/*" ]] && continue
            exclude+=("--exclude=$(basename "$cpath")")
        done < <(grep -F "$path" "$CONF")
    fi

    if [[ "$MODE" == "backup" ]]; then
        backup "$path" "$interval" "${exclude[@]}"
    elif [[ "$MODE" == "restore" ]]; then
        restore "$path" "${exclude[@]}"
    fi
done < "$CONF"
