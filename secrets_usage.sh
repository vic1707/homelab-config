#!/usr/bin/env bash

set -euo pipefail

unused_secrets=()
for secret in $(gopass ls -f); do
    output=$(rg --no-heading --line-number --fixed-strings "$secret" . || true)

    if [[ -z ${output} ]]; then
        unused_secrets+=("$secret")
        break
    fi

    match_count=$(wc -l <<< "$output")
    echo -e "\033[1;34m🔐 Secret:\033[0m $secret"
    echo -e "\033[1;36m   ↳ Found $match_count time(s)\033[0m"

    while IFS=: read -r file line _; do
        echo -e "\033[1;32m→ $file:$line\033[0m"
        bat --style=numbers --color=always --highlight-line "$line" --line-range "$line:$line" "$file"
    done <<< "$output"
    echo
done

if ! ((${#unused_secrets[@]} > 0)); then exit 0; fi

echo -e "\033[1;33m⚠️ Unused secrets:\033[0m"
for secret in "${unused_secrets[@]}"; do
    echo -e "  - $secret"
done
