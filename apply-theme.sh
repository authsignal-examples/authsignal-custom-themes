#!/usr/bin/env bash
# Applies a theme folder to an Authsignal tenant's pre-built UI via the Management API.
#
# A theme folder holds theme.json (design tokens) and, optionally, template.html
# (a custom template). The current theme is backed up before anything changes.
#
# Usage:  MANAGEMENT_API_KEY=xxxx ./apply-theme.sh themes/brutalist
#         MANAGEMENT_API_KEY=xxxx API=https://au.api.authsignal.com ./apply-theme.sh themes/terminal
#         MANAGEMENT_API_KEY=xxxx ./apply-theme.sh --restore backups/theme-20260928-120000.json
#         MANAGEMENT_API_KEY=xxxx ./apply-theme.sh --dry-run themes/aurora   # print the payload only

set -euo pipefail

# Keys can live in a .env file next to this script
[[ -f "$(dirname "$0")/.env" ]] && source "$(dirname "$0")/.env"

API="${API:-https://api.authsignal.com}"
ENDPOINT="$API/v1/management/theme"
DRY_RUN=false

if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=true
  shift
fi

if [[ $# -ne 1 && "${1:-}" != "--restore" ]] || [[ "${1:-}" == "--restore" && $# -ne 2 ]]; then
  sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'
  exit 1
fi

if [[ "$1" == "--restore" ]]; then
  # A backup is a GET /theme response. Add an empty template when it had none,
  # so a template from a later theme doesn't linger.
  payload="$(jq '.template //= ""' "$2")"
else
  dir="${1%/}"
  [[ -f "$dir/theme.json" ]] || { echo "No theme.json in $dir" >&2; exit 1; }

  template=""
  [[ -f "$dir/template.html" ]] && template="$(cat "$dir/template.html")"

  # Stamp a revision into the first <style> so show-theme.sh can tell when
  # the pre-built UI (which caches themes for about a minute) serves this version
  REV="${REV:-$(date +%s)}"
  template="${template/<style>/<style>/* rev $REV */}"

  # PATCH merges into the existing theme, so always send a template ("" clears it).
  # Themes without their own darkMode get the light tokens copied in, so the
  # theme looks the same whatever the visitor's OS color scheme is.
  payload="$(jq --arg template "$template" '
    .template = $template
    # PATCH merges, so a heading or button font from a previous theme would
    # linger. Fall back to the body font for any typeface this theme leaves out.
    | if .typography.text then
        .typography.display //= .typography.text | .typography.button //= .typography.text
      else . end
    | if has("darkMode") then . else
        .darkMode = ({primaryColor, colors, pageBackground, borders, shadows}
                     | with_entries(select(.value != null)))
      end
  ' "$dir/theme.json")"

  if (( ${#template} > 20000 )); then
    echo "template.html is ${#template} characters; the API limit is 20000." >&2
    exit 1
  fi
fi

if $DRY_RUN; then
  echo "$payload"
  exit 0
fi

: "${MANAGEMENT_API_KEY:?Set MANAGEMENT_API_KEY to your Management API secret key}"

mkdir -p backups
backup="backups/theme-$(date +%Y%m%d-%H%M%S).json"
curl -fsS -u "$MANAGEMENT_API_KEY:" "$ENDPOINT" > "$backup"
echo "Backed up current theme to $backup"

curl -fsS -X PATCH -u "$MANAGEMENT_API_KEY:" \
  -H "Content-Type: application/json" \
  --data "$payload" \
  "$ENDPOINT" > /dev/null

echo "Applied ${2:-$1}"
