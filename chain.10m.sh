#!/bin/bash
# ═══════════════════════════════════════════════════════════════
#  Chain — macOS menu bar (SwiftBar / xbar plugin)   [optional]
#
#  brew install --cask swiftbar
#  then drop this file in your SwiftBar plugin folder, chmod +x it.
#  Filename must keep the .10m. part — that's the refresh interval.
#
#  <bitbar.title>Chain</bitbar.title>
#  <bitbar.version>1.0</bitbar.version>
#  <bitbar.desc>Today's X and the current chain, in the menu bar.</bitbar.desc>
# ═══════════════════════════════════════════════════════════════

# Credentials come from the file install-mac.command writes, so nothing
# secret lives in this repo.
CONFIG="$HOME/Library/Application Support/Chain/config"
[ -f "$CONFIG" ] || { echo "chain: not set up"; exit 0; }
# shellcheck disable=SC1090
source "$CONFIG"
SUPABASE_URL="$CHAIN_URL"; SUPABASE_KEY="$CHAIN_KEY"; APP_URL="${CHAIN_APP_URL:-}"

json="$(curl -sS -m 10 -X POST "$SUPABASE_URL/rest/v1/rpc/chain_status" \
  -H "apikey: $SUPABASE_KEY" -H "Authorization: Bearer $SUPABASE_KEY" \
  -H "Content-Type: application/json" -d '{}' 2>/dev/null)"

if [ -z "$json" ]; then
  echo "✕ ?"
  echo "---"
  echo "Can't reach the database"
  exit 0
fi

get() { echo "$json" | /usr/bin/python3 -c "import sys,json;d=json.load(sys.stdin);print(d[0].get('$1'))"; }

w=$(get w); c=$(get c); r=$(get r); streak=$(get streak)

if [ "$r" = "True" ]; then          glyph="◌"
elif [ "$w" = "True" ] && [ "$c" = "True" ]; then glyph="✕"
elif [ "$w" = "True" ] || [ "$c" = "True" ]; then glyph="╱"
else                                glyph="·"
fi

# red only when the day is complete
if [ "$w" = "True" ] && [ "$c" = "True" ]; then
  echo "$glyph $streak | color=#D33726 font=Menlo size=13"
else
  echo "$glyph $streak | font=Menlo size=13"
fi

echo "---"
[ "$w" = "True" ] && echo "✓ Workout" || echo "○ Workout"
[ "$c" = "True" ] && echo "✓ Content" || echo "○ Content"
echo "---"
echo "$streak-day chain"
echo "Open Chain | href=$APP_URL"
echo "Refresh | refresh=true"
