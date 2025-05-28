#!/usr/bin/env bash

set -euo pipefail

declare -A MATCHES
for secret in $(gopass ls -f); do
    output=$(rg --no-heading --line-number --fixed-strings "$secret" . || true)
    MATCHES["$secret"]="$output"
done

case "${1:-secrets}" in
    secrets)
        echo "### Secret references by secret path:"
        echo

        unused_secrets=()

        for secret in "${!MATCHES[@]}"; do
            if [[ -z ${MATCHES[$secret]} ]]; then
                unused_secrets+=("$secret")
                break
            fi
            echo -e "\033[1;34m🔐 Secret:\033[0m $secret"
            while IFS=: read -r file line _; do
                echo -e "\033[1;32m→ $file:$line\033[0m"
                bat --style=numbers --color=always --highlight-line "$line" --line-range "$line:$line" "$file"
            done <<< "${MATCHES[$secret]}"
            echo
        done

        if ! ((${#unused_secrets[@]} > 0)); then exit 0; fi
        echo -e "\033[1;33m⚠️ Unused secrets:\033[0m"
        for secret in "${unused_secrets[@]}"; do
            echo -e "  - $secret"
        done
        ;;
    files)
        ;;
    *)
        echo "Invalid mode: $1"
        echo "Use 'secrets' or 'files'"
        exit 1
        ;;
esac
