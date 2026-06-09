#!/usr/bin/env bash
# check-old-prs.sh — notifies you of open PRs authored by you that are older than 7 days.
# Scheduled via ~/Library/LaunchAgents/com.harveytaylor.check-old-prs.plist

set -euo pipefail

THRESHOLD_DAYS=7

# Locate gh and terminal-notifier — may not be on PATH when run by launchd
GH=""
for candidate in /opt/homebrew/bin/gh /usr/local/bin/gh /usr/bin/gh; do
  if [[ -x "$candidate" ]]; then GH="$candidate"; break; fi
done

NOTIFIER=""
for candidate in /opt/homebrew/bin/terminal-notifier /usr/local/bin/terminal-notifier; do
  if [[ -x "$candidate" ]]; then NOTIFIER="$candidate"; break; fi
done

if [[ -z "$GH" ]]; then
  echo "ERROR: gh CLI not found." >&2
  exit 1
fi

prs=$("$GH" search prs --author "@me" --state open \
  --json number,title,createdAt,url 2>/dev/null)

if [[ -z "$prs" || "$prs" == "[]" ]]; then
  echo "No open PRs found."
  exit 0
fi

# Process all PRs in one python3 call: print tab-separated age_days, title, url
echo "$prs" | python3 -c "
import sys, json
from datetime import datetime, timezone
threshold = int(sys.argv[1])
now = datetime.now(timezone.utc)
for pr in json.load(sys.stdin):
    created = datetime.fromisoformat(pr['createdAt'].replace('Z', '+00:00'))
    age_days = (now - created).days
    print(f\"{age_days}\t{pr['title']}\t{pr['url']}\")
" "$THRESHOLD_DAYS" | while IFS=$'\t' read -r age_days title url; do
  if (( age_days >= THRESHOLD_DAYS )); then
    if [[ -n "$NOTIFIER" ]]; then
      "$NOTIFIER" -title "⏰ Old PR — ${age_days} days old" -message "$title" -subtitle "$url" -open "$url" -sound Glass
    else
      osascript \
        -e 'on run argv' \
        -e 'display notification (item 1 of argv) with title (item 2 of argv) subtitle (item 3 of argv) sound name "Glass"' \
        -e 'end run' \
        -- "$title" "⏰ Old PR — ${age_days} days old" "$url"
    fi
    echo "[NOTIFY] ${age_days}d — ${title} (${url})"
  else
    echo "[OK]     ${age_days}d — ${title}"
  fi
done

echo ""
echo "Done checking PRs (threshold: ${THRESHOLD_DAYS} days)."
