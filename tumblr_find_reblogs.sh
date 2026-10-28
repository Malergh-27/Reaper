#!/usr/bin/env bash
# Find every post on BLOG that was reblogged from SOURCE, using Tumblr's official v2 API.
# Usage:  TUMBLR_KEY=yourConsumerKey ./tumblr_find_reblogs.sh geekgirles smallpwbbles [tag]
# Get a free key by registering an app at https://www.tumblr.com/oauth/apps
set -euo pipefail

BLOG="${1:?blog name}"; SOURCE="${2:?source blog to match}"; TAG="${3:-}"
# Key comes from $TUMBLR_KEY, or from a file holding only the key.
KEYFILE="${TUMBLR_KEY_FILE:-$HOME/.config/reaper/tumblr_key}"
[ -z "${TUMBLR_KEY:-}" ] && [ -r "$KEYFILE" ] && TUMBLR_KEY=$(tr -d '[:space:]' < "$KEYFILE")
: "${TUMBLR_KEY:?set TUMBLR_KEY, or put your OAuth consumer key in $KEYFILE}"
# Optional user token (from tumblr_oauth.sh): lets the scan see what your logged-in account sees,
# i.e. dashboard-only ("hidden") blogs and mature content, instead of the anonymous view.
TOKENFILE="${TUMBLR_TOKEN_FILE:-$HOME/.config/reaper/tumblr_token}"
AUTH=()
load_token() { [ -r "$TOKENFILE" ] && AUTH=(-H "Authorization: Bearer $(jq -r .access_token "$TOKENFILE")"); }
refresh_token() { "$(dirname "$0")/tumblr_oauth.sh" refresh >&2 && load_token; }
# Tokens expire after ~42 minutes, so refresh up front and again on any 401 mid-scan.
[ -r "$TOKENFILE" ] && refresh_token || load_token
command -v jq >/dev/null || { echo "jq is required (sudo apt install jq)"; exit 1; }

API="https://api.tumblr.com/v2/blog/$BLOG/posts"
# Note: fields[posts] is rejected by the API (error 3001), so full post objects come back.
FIELDS='id,post_url,timestamp,reblogged_from_name,reblogged_root_name'
# Docs say limit is 1-20, but the API returns up to 50. filter=text shrinks a 50-post page from ~1 MB to ~260 KB.
LIMIT=50
BEFORE=""; PAGES=0; FOUND=0

while :; do
  URL="$API?api_key=$TUMBLR_KEY&limit=$LIMIT&reblog_info=true&filter=text"
  [ -n "$TAG" ]    && URL="$URL&tag=$(printf %s "$TAG" | jq -sRr @uri)"
  [ -n "$BEFORE" ] && URL="$URL&before=$BEFORE"

  BODY=$(curl -sg "${AUTH[@]}" -w '\n%{http_code}' "$URL")
  CODE=${BODY##*$'\n'}; JSON=${BODY%$'\n'*}
  if [ "$CODE" = 429 ]; then echo "rate limited, sleeping 60s" >&2; sleep 60; continue; fi
  if [ "$CODE" = 401 ] && [ ${#AUTH[@]} -gt 0 ]; then echo "token expired, refreshing" >&2; refresh_token; continue; fi
  [ "$CODE" = 200 ] || { echo "HTTP $CODE: $(echo "$JSON" | jq -r '.meta.msg // .' 2>/dev/null)" >&2; exit 1; }

  PAGES=$((PAGES+1))
  N=$(echo "$JSON" | jq '.response.posts | length')
  [ "$N" -eq 0 ] && break

  # Print matches from this page
  HITS=$(echo "$JSON" | jq -r --arg s "$SOURCE" \
    '.response.posts[] | select(.reblogged_from_name==$s or .reblogged_root_name==$s) | .post_url')
  if [ -n "$HITS" ]; then echo "$HITS"; FOUND=$((FOUND + $(echo "$HITS" | wc -l))); fi

  # Page by timestamp: offset is capped, "before" is not.
  BEFORE=$(echo "$JSON" | jq '.response.posts[-1].timestamp')
  [ "$N" -lt "$LIMIT" ] && break
done
echo "scanned $PAGES pages, found $FOUND matching post(s)" >&2
