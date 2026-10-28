#!/usr/bin/env bash
# One-time OAuth2 setup for the Reaper app. Exchanges an authorization code for a user token,
# or refreshes an existing token. Writes $HOME/.config/reaper/tumblr_token (JSON).
# Usage:  ./tumblr_oauth.sh <code-from-redirect-url>     or     ./tumblr_oauth.sh refresh
set -euo pipefail
D="$HOME/.config/reaper"
KEY=$(tr -d '[:space:]' < "$D/tumblr_key")
SECRET=$(tr -d '[:space:]' < "$D/tumblr_secret")   # paste your consumer secret into this file yourself
if [ "${1:-}" = refresh ]; then
  RT=$(jq -r .refresh_token "$D/tumblr_token")
  RESP=$(curl -s -X POST https://api.tumblr.com/v2/oauth2/token -H 'Content-Type: application/json' \
    -d "{\"grant_type\":\"refresh_token\",\"client_id\":\"$KEY\",\"client_secret\":\"$SECRET\",\"refresh_token\":\"$RT\"}")
else
  CODE="${1:?authorization code}"
  RESP=$(curl -s -X POST https://api.tumblr.com/v2/oauth2/token -H 'Content-Type: application/json' \
    -d "{\"grant_type\":\"authorization_code\",\"code\":\"$CODE\",\"client_id\":\"$KEY\",\"client_secret\":\"$SECRET\",\"redirect_uri\":\"https://github.com/Malergh-27/Reaper\"}")
fi
if echo "$RESP" | jq -e .access_token >/dev/null 2>&1; then
  umask 077; echo "$RESP" > "$D/tumblr_token"
  echo "token saved; scope=$(echo "$RESP" | jq -r .scope) expires_in=$(echo "$RESP" | jq -r .expires_in)s"
else
  echo "token request failed: $(echo "$RESP" | jq -c . 2>/dev/null || echo "$RESP")" >&2; exit 1
fi
