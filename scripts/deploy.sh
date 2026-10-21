#!/usr/bin/env bash
set -euo pipefail

API_BASE_URL="https://www.weavefox.cn/api/open/v1"
API_KEY="${INPUT_API_KEY:-}"
PUBLIC_ID="${INPUT_PUBLIC_ID:-}"
DIST_DIR="${INPUT_DIST_DIR:-dist}"
CHANGELOG="${INPUT_CHANGELOG:-}"

fail() { printf '::error::%s\n' "$*" >&2; exit 1; }

# call METHOD PATH [BODY] [TOKEN]
call() {
  local args=(-sS -X "$1" -H "Authorization: Bearer ${4:-$API_KEY}" -w $'\n%{http_code}')
  [ -n "${3:-}" ] && args+=(-H 'Content-Type: application/json' -d "$3")

  local response status payload
  response="$(curl "${args[@]}" "$API_BASE_URL$2")" || fail "curl failed: $1 $2"
  status="${response##*$'\n'}"
  payload="${response%$'\n'*}"

  if [ "${status:0:1}" != "2" ] || [ "$(jq -r '.code' <<<"$payload" 2>/dev/null)" != "0" ]; then
    local message
    message="$(jq -r '.message // empty' <<<"$payload" 2>/dev/null)"
    fail "$1 $2 failed (HTTP $status): ${message:-$payload}"
  fi
  printf '%s' "$payload"
}

[ -n "$API_KEY" ] || fail "api-key is required"
[ -n "$PUBLIC_ID" ] || fail "public-id is required"
[ -f "$DIST_DIR/index.html" ] || fail "index.html not found in $DIST_DIR"
[ -n "$CHANGELOG" ] || CHANGELOG="Deploy ${GITHUB_SHA:0:7}"

work_dir="$(mktemp -d)"
trap 'rm -rf "$work_dir"' EXIT
(cd "$DIST_DIR" && zip -qr "$work_dir/artifact.zip" .) || fail "Failed to package $DIST_DIR"

token="$(call POST "/apps/$PUBLIC_ID/upload-token" | jq -r '.data.token // empty')"
[ -n "$token" ] || fail "upload-token response did not contain a token"
printf '::add-mask::%s\n' "$token"

upload="$(curl -sS -X POST -H "Authorization: Bearer $token" \
  -F "file=@$work_dir/artifact.zip;type=application/zip" \
  "$API_BASE_URL/apps/$PUBLIC_ID/upload-artifact-zip")" || fail "Upload request failed"
artifact_zip_url="$(jq -r '.data.artifactZipUrl // empty' <<<"$upload" 2>/dev/null)"
[ -n "$artifact_zip_url" ] || fail "Upload failed: $(jq -r '.message // .' <<<"$upload" 2>/dev/null || printf '%s' "$upload")"

body="$(jq -n --arg url "$artifact_zip_url" --arg changelog "$CHANGELOG" \
  '{artifactZipUrl: $url, changelog: $changelog}')"
version="$(call POST "/apps/$PUBLIC_ID/versions" "$body" | jq -r '.data.version // empty')"
[ -n "$version" ] || fail "Create version response did not contain a version"

call POST "/apps/$PUBLIC_ID/versions/$version/deploy" '{}' >/dev/null

if [ -n "${GITHUB_OUTPUT:-}" ]; then
  printf 'version=%s\nartifact-zip-url=%s\n' "$version" "$artifact_zip_url" >> "$GITHUB_OUTPUT"
fi

printf 'Deployed %s %s\n' "$PUBLIC_ID" "$version"
