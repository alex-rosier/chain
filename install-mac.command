#!/bin/bash
# ═══════════════════════════════════════════════════════════════
#  Chain — Mac 5pm nudge
#
#  Installs a launchd job that wakes at 17:00 and 20:30, asks the
#  database whether today is still open, and fires a native macOS
#  notification if it is. No app running, no browser tab, no tokens.
#
#  Run:      bash install-mac.command
#  Remove:   bash install-mac.command --uninstall
#
#  Your publishable key is asked for once and stored OUTSIDE this repo,
#  in ~/Library/Application Support/Chain/config — so it never gets
#  committed.
# ═══════════════════════════════════════════════════════════════
set -euo pipefail

SUPABASE_URL="https://owuractrglhippvuilxa.supabase.co"

LABEL="com.alexrosier.chain.nudge"
DIR="$HOME/Library/Application Support/Chain"
CONFIG="$DIR/config"
SCRIPT="$DIR/nudge.sh"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"

if [[ "${1:-}" == "--uninstall" ]]; then
  launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || launchctl unload "$PLIST" 2>/dev/null || true
  rm -f "$PLIST"; rm -rf "$DIR"
  echo "Chain nudge removed."
  exit 0
fi

mkdir -p "$DIR" "$HOME/Library/LaunchAgents"

# ── credentials, asked once, kept out of the repo ─────────────
if [[ -f "$CONFIG" ]]; then
  # shellcheck disable=SC1090
  source "$CONFIG"
fi

if [[ -z "${CHAIN_KEY:-}" ]]; then
  echo "Supabase publishable key (starts with sb_publishable_):"
  read -r CHAIN_KEY
fi
if [[ -z "$CHAIN_KEY" ]]; then
  echo "No key given — nothing installed." >&2
  exit 1
fi

APP_URL="${CHAIN_APP_URL:-}"
if [[ -z "$APP_URL" ]]; then
  echo "App URL (press return to skip — only used to make the notification clickable):"
  read -r APP_URL
fi

umask 077
cat > "$CONFIG" <<EOF
CHAIN_URL="$SUPABASE_URL"
CHAIN_KEY="$CHAIN_KEY"
CHAIN_APP_URL="$APP_URL"
EOF
chmod 600 "$CONFIG"

# ── the check itself ──────────────────────────────────────────
cat > "$SCRIPT" <<'EOF'
#!/bin/bash
# Asks the database for a nudge line. An empty answer means today is done.
CONFIG="$HOME/Library/Application Support/Chain/config"
[ -f "$CONFIG" ] || exit 0
# shellcheck disable=SC1090
source "$CONFIG"

msg="$(curl -sS -m 15 -X POST "$CHAIN_URL/rest/v1/rpc/chain_nudge" \
  -H "apikey: $CHAIN_KEY" \
  -H "Authorization: Bearer $CHAIN_KEY" \
  -H "Content-Type: application/json" \
  -H "Accept: text/plain" \
  -d '{}' 2>/dev/null)" || exit 0

# strip JSON quoting if PostgREST hands back "..." instead of raw text
msg="${msg%\"}"; msg="${msg#\"}"

[ -z "$msg" ] && exit 0
[ "$msg" = "null" ] && exit 0

safe="${msg//\"/\\\"}"
/usr/bin/osascript -e "display notification \"$safe\" with title \"Chain\" subtitle \"The day is still open\" sound name \"Ping\""
echo "$(date '+%F %H:%M') $msg" >> "$HOME/Library/Application Support/Chain/nudge.log"
EOF

chmod +x "$SCRIPT"

# ── the schedule ──────────────────────────────────────────────
cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key>
  <array><string>/bin/bash</string><string>$SCRIPT</string></array>
  <key>StartCalendarInterval</key>
  <array>
    <dict><key>Hour</key><integer>17</integer><key>Minute</key><integer>0</integer></dict>
    <dict><key>Hour</key><integer>20</integer><key>Minute</key><integer>30</integer></dict>
  </array>
  <key>RunAtLoad</key><false/>
  <key>StandardErrorPath</key><string>$DIR/error.log</string>
</dict>
</plist>
EOF

launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST" 2>/dev/null || launchctl load "$PLIST"

echo
echo "Installed. Checks at 17:00 and 20:30 daily."
echo "Running it once now to prove the whole path works…"
bash "$SCRIPT" || true
echo
echo "If today is already complete you'll see nothing — that's correct."
echo "If today is still open and no banner appeared, allow notifications for"
echo "Script Editor in System Settings → Notifications."
