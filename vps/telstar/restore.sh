#!/usr/bin/env bash
set -euo pipefail

LOG="/var/log/restore-check.log"

SYNC_PATHS_FILE="$1"
STORAGEBOX_ROOT="$2"

echo "[INFO] Starting restore script..."
echo "[INFO] Using SYNC_PATHS_FILE: ${SYNC_PATHS_FILE}"
echo "[INFO] Using STORAGEBOX_ROOT: ${STORAGEBOX_ROOT}"

if [[ ! -r "${SYNC_PATHS_FILE}" ]]; then
  echo "[ERROR] Cannot read sync paths file: ${SYNC_PATHS_FILE}" >&2
  exit 1
fi

# Loop over each path using cat
for path in $(cat "$SYNC_PATHS_FILE"); do
  [[ -z "$path" ]] && continue

  if [[ "${path:0:1}" != "/" ]]; then
    echo "[WARN] Ignoring non-absolute path: '$path'"
    continue
  fi

  SOURCE="${STORAGEBOX_ROOT}${path}"
  if [[ ! -e "$SOURCE" ]]; then
    echo "[WARN] Skipping '$path' – not present in backup."
    continue
  fi

  echo "[INFO] Checking path: $path"
  echo "[INFO] Restoring: $path"
  /usr/bin/rsync --verbose \
    --archive --recursive \
    --delete \
    --fake-super -M--super \
    --log-file=/var/log/sync-to-storagebox.log \
    "$SOURCE" "$path"
done

echo "[INFO] Restore complete."
