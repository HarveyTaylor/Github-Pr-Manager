#!/usr/bin/env bash
# install.sh — installs dependencies and schedules check-old-prs.sh as a daily LaunchAgent.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_PATH="$SCRIPT_DIR/check-old-prs.sh"
PLIST_LABEL="com.harveytaylor.check-old-prs"
PLIST_PATH="$HOME/Library/LaunchAgents/${PLIST_LABEL}.plist"
LOG_DIR="$HOME/Library/Logs"

# ── Helpers ────────────────────────────────────────────────────────────────────

info()    { echo "  ✔  $*"; }
section() { echo ""; echo "▶ $*"; }
abort()   { echo ""; echo "  ✘  ERROR: $*" >&2; exit 1; }

# ── Check OS ───────────────────────────────────────────────────────────────────

[[ "$(uname)" == "Darwin" ]] || abort "This script only supports macOS."

# ── Check / install Homebrew ───────────────────────────────────────────────────

section "Checking Homebrew..."
if ! command -v brew &>/dev/null; then
  echo "  Homebrew not found. Installing..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
else
  info "Homebrew already installed."
fi

# ── Check / install gh ────────────────────────────────────────────────────────

section "Checking GitHub CLI (gh)..."
if ! command -v gh &>/dev/null; then
  echo "  Installing gh..."
  brew install gh
else
  info "gh already installed ($(gh --version | head -1))."
fi

# Ensure gh is authenticated
if ! gh auth status &>/dev/null; then
  echo ""
  echo "  gh is not authenticated. Starting login..."
  gh auth login
fi
info "gh authenticated."

# ── Check / install terminal-notifier ─────────────────────────────────────────

section "Checking terminal-notifier..."
if ! command -v terminal-notifier &>/dev/null; then
  echo "  Installing terminal-notifier..."
  brew install terminal-notifier
else
  info "terminal-notifier already installed."
fi

# ── Prompt for schedule time ───────────────────────────────────────────────────

section "Schedule"
echo ""
echo "  What time should the daily PR check run? (24-hour format)"
echo ""

while true; do
  read -rp "  Enter time [HH:MM, default 09:00]: " TIME_INPUT
  TIME_INPUT="${TIME_INPUT:-09:00}"

  if [[ "$TIME_INPUT" =~ ^([01]?[0-9]|2[0-3]):([0-5][0-9])$ ]]; then
    HOUR="${BASH_REMATCH[1]#0}"   # strip leading zero so plist integer is valid
    MINUTE="${BASH_REMATCH[2]#0}"
    HOUR="${HOUR:-0}"
    MINUTE="${MINUTE:-0}"
    break
  else
    echo "  Invalid format. Please use HH:MM (e.g. 09:00 or 17:30)."
  fi
done

info "Scheduled for $(printf '%02d:%02d' "$HOUR" "$MINUTE") daily."

# ── Make the script executable ─────────────────────────────────────────────────

section "Installing script..."
chmod +x "$SCRIPT_PATH"
info "check-old-prs.sh is executable."

# ── Write the LaunchAgent plist ────────────────────────────────────────────────

section "Creating LaunchAgent..."
mkdir -p "$HOME/Library/LaunchAgents"

cat > "$PLIST_PATH" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>${PLIST_LABEL}</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>${SCRIPT_PATH}</string>
  </array>
  <key>StartCalendarInterval</key>
  <dict>
    <key>Hour</key>
    <integer>${HOUR}</integer>
    <key>Minute</key>
    <integer>${MINUTE}</integer>
  </dict>
  <key>StandardOutPath</key>
  <string>${LOG_DIR}/check-old-prs.log</string>
  <key>StandardErrorPath</key>
  <string>${LOG_DIR}/check-old-prs.error.log</string>
  <key>RunAtLoad</key>
  <false/>
</dict>
</plist>
EOF

info "Plist written to $PLIST_PATH."

# ── Load (or reload) the LaunchAgent ──────────────────────────────────────────

section "Loading LaunchAgent..."
# Unload first in case it was previously installed with a different time
launchctl unload "$PLIST_PATH" 2>/dev/null || true
launchctl load "$PLIST_PATH"
info "LaunchAgent loaded."

# ── Done ───────────────────────────────────────────────────────────────────────

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ✔  Installation complete!"
echo "     The PR check will run daily at $(printf '%02d:%02d' "$HOUR" "$MINUTE")."
echo "     Logs: $LOG_DIR/check-old-prs.log"
echo ""
echo "  To run it now:  bash $SCRIPT_PATH"
echo "  To uninstall:   launchctl unload $PLIST_PATH && rm $PLIST_PATH"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
