#!/bin/bash
# Claude Usage Monitor for SwiftBar
# Refreshes every 5 minutes (filename convention: claude-usage.5m.sh)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HELPER="$SCRIPT_DIR/claude-usage-helper.py"

# Run helper and capture output
output=$(python3 "$HELPER" 2>/dev/null)
status=$(echo "$output" | grep "^STATUS:" | cut -d: -f2)

if [ "$status" = "NO_TOKEN" ] || [ "$status" = "API_ERROR" ] || [ -z "$status" ]; then
    echo "🟡 Claude|color=gray"
    echo "---"
    echo "⚠️ Not logged in|color=red"
    echo "---"
    echo "Run this in Terminal to log in:|color=#888888"
    echo "~/local-npm/node_modules/.bin/claude|font=Menlo size=11"
    echo "---"
    echo "Refresh|refresh=true"
    exit 0
fi

# Parse values
session_pct=$(echo "$output" | grep "^SESSION:" | cut -d: -f2)
weekly_pct=$(echo "$output" | grep "^WEEKLY:" | cut -d: -f2)
session_reset=$(echo "$output" | grep "^SESSION_RESET:" | cut -d: -f2)
weekly_reset=$(echo "$output" | grep "^WEEKLY_RESET:" | cut -d: -f2)
last_check=$(echo "$output" | grep "^LAST_CHECK:" | cut -d: -f2-)

[ -z "$session_pct" ] && session_pct=0
[ -z "$weekly_pct" ] && weekly_pct=0
[ -z "$session_reset" ] && session_reset=0
[ -z "$weekly_reset" ] && weekly_reset=0

# --- Menu bar icon ---
if [ "$session_pct" -ge 90 ]; then
    icon="❤️‍🔥"
elif [ "$session_pct" -ge 60 ]; then
    icon="🧡"
else
    icon="💚"
fi

echo "${icon} ${session_pct}%"
echo "---"

# --- Dropdown ---
echo "🧡 Claude (Pro)|size=14"
echo ""

# Format reset times
format_reset() {
    local epoch=$1
    local now=$(date +%s)
    local diff=$(( epoch - now ))
    if [ "$diff" -le 0 ]; then echo "now"; return; fi
    if [ "$diff" -lt 3600 ]; then echo "~$((diff / 60))m"
    elif [ "$diff" -lt 86400 ]; then echo "~$((diff / 3600))h$((diff % 3600 / 60))m"
    else echo "~$((diff / 86400))d"; fi
}

# Session bar
session_reset_label=""
[ "$session_reset" -gt 0 ] && session_reset_label=" ($(format_reset "$session_reset"))"

session_filled=$(( session_pct * 10 / 100 ))
[ "$session_filled" -gt 10 ] && session_filled=10
session_empty=$(( 10 - session_filled ))
session_bar=""
for ((i=0; i<session_filled; i++)); do session_bar="${session_bar}🟩"; done
for ((i=0; i<session_empty; i++)); do session_bar="${session_bar}⬜"; done

if [ "$session_pct" -ge 90 ]; then scolor="red"
elif [ "$session_pct" -ge 60 ]; then scolor="orange"
else scolor="#4CAF50"; fi

echo "Session: ${session_bar}  ${session_pct}%${session_reset_label}|color=$scolor font=Menlo size=12"

# Weekly bar
weekly_reset_label=""
[ "$weekly_reset" -gt 0 ] && weekly_reset_label=" ($(format_reset "$weekly_reset"))"

weekly_filled=$(( weekly_pct * 10 / 100 ))
[ "$weekly_filled" -gt 10 ] && weekly_filled=10
weekly_empty=$(( 10 - weekly_filled ))
weekly_bar=""
for ((i=0; i<weekly_filled; i++)); do weekly_bar="${weekly_bar}🟩"; done
for ((i=0; i<weekly_empty; i++)); do weekly_bar="${weekly_bar}⬜"; done

if [ "$weekly_pct" -ge 90 ]; then wcolor="red"
elif [ "$weekly_pct" -ge 60 ]; then wcolor="orange"
else wcolor="#4CAF50"; fi

echo "Weekly:  ${weekly_bar}  ${weekly_pct}%${weekly_reset_label}|color=$wcolor font=Menlo size=12"

echo ""

# Stale warning
if [ "$status" = "STALE" ]; then
    echo "⚡ Using cached data (API rate limited)|color=#FF9800 size=11"
fi

# Last check time
if [ -n "$last_check" ]; then
    echo "Last checked: $last_check|color=#888888 size=11"
fi

echo "---"
echo "Refresh|refresh=true"
echo "Open Claude|href=https://claude.ai"
echo "---"
echo "Setup: ~/local-npm/node_modules/.bin/claude|color=#888888 size=10 font=Menlo"
