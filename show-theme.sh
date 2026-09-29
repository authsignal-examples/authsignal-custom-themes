#!/usr/bin/env bash
# Applies a theme, waits until the pre-built UI serves it (the theme is cached
# for about a minute), then prints a fresh preview link. Links expire after ~2 minutes.
#
# Usage:  ./show-theme.sh themes/terminal

set -euo pipefail
cd "$(dirname "$0")"

theme_dir="${1%/}"
name="$(jq -r .name "$theme_dir/theme.json")"

export REV="$(date +%s)"
./apply-theme.sh "$theme_dir"
marker="/* rev $REV */"

printf "Waiting for the pre-built UI to pick up \"%s\"" "$name"
for _ in $(seq 1 30); do
  html="$(curl -fsS "$(./preview-url.sh)" || true)"
  if [[ "$html" == *"$marker"* ]]; then
    echo " ready"
    ./preview-url.sh
    exit 0
  fi
  printf "."
  sleep 5
done

echo " timed out" >&2
exit 1
