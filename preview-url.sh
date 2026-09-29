#!/usr/bin/env bash
# Prints a fresh pre-built UI link for a brand-new test user, so it opens on the
# "Set up authentication" screen. Uses the Server API (not the Management API).
#
# Usage:  SERVER_API_KEY=xxxx ./preview-url.sh
#         SERVER_API_KEY=xxxx API=https://au.api.authsignal.com ./preview-url.sh

set -euo pipefail

# Keys can live in a .env file next to this script
[[ -f "$(dirname "$0")/.env" ]] && source "$(dirname "$0")/.env"

API="${API:-https://api.authsignal.com}"
: "${SERVER_API_KEY:?Set SERVER_API_KEY to the Server API secret key of the same tenant}"

user_id="theme-preview-$(date +%s)"

curl -fsS -X POST -u "$SERVER_API_KEY:" \
  -H "Content-Type: application/json" \
  --data '{"redirectUrl": "https://example.com"}' \
  "$API/v1/users/$user_id/actions/themePreview" | jq -r '.url'
