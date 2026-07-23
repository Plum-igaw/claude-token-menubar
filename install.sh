#!/bin/bash
# Claude Token Menubar - One-click installer
# Shows Claude Code usage (session/weekly) in macOS menu bar via SwiftBar
set -e

REPO_URL="https://raw.githubusercontent.com/Plum-igaw/claude-token-menubar/main"
PLUGIN_DIR="$HOME/swiftbar-plugins"
LAUNCH_AGENTS="$HOME/Library/LaunchAgents"

echo ""
echo "  💚 Claude Token Menubar - Installer"
echo "  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# --- Step 1: Check dependencies ---
if ! command -v python3 &>/dev/null; then
    echo "  ❌ python3 not found. Please install Python 3."
    exit 1
fi
echo "  ✓ python3 found"

# --- Step 2: Install SwiftBar if needed ---
if [ ! -d "/Applications/SwiftBar.app" ]; then
    echo "  ⬇ Installing SwiftBar..."
    SWIFTBAR_URL="https://github.com/swiftbar/SwiftBar/releases/download/v1.4.3/SwiftBar.zip"
    curl -sL -o /tmp/SwiftBar.zip "$SWIFTBAR_URL"
    unzip -qo /tmp/SwiftBar.zip -d /tmp/SwiftBar_extracted
    cp -R /tmp/SwiftBar_extracted/SwiftBar.app /Applications/
    rm -rf /tmp/SwiftBar.zip /tmp/SwiftBar_extracted
    echo "  ✓ SwiftBar installed"
else
    echo "  ✓ SwiftBar already installed"
fi

# --- Step 3: Create plugin directory ---
mkdir -p "$PLUGIN_DIR"
echo "  ✓ Plugin folder: $PLUGIN_DIR"

# --- Step 4: Download plugin files ---
echo "  ⬇ Downloading plugin..."
curl -sL "$REPO_URL/claude-usage.5m.sh" -o "$PLUGIN_DIR/claude-usage.5m.sh"
curl -sL "$REPO_URL/claude-usage-helper.py" -o "$PLUGIN_DIR/.claude-usage-helper.py"
curl -sL "$REPO_URL/claude-token-refresh.py" -o "$PLUGIN_DIR/.claude-token-refresh.py"
chmod +x "$PLUGIN_DIR/claude-usage.5m.sh"
echo "  ✓ Plugin installed"

# --- Step 5: Setup auto token refresh (every 4 hours) ---
echo "  ⬇ Setting up auto token refresh..."
mkdir -p "$LAUNCH_AGENTS"
cat > "$LAUNCH_AGENTS/com.claude.token-refresh.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.claude.token-refresh</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/bin/python3</string>
        <string>${PLUGIN_DIR}/.claude-token-refresh.py</string>
    </array>
    <key>StartInterval</key>
    <integer>14400</integer>
    <key>RunAtLoad</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/tmp/claude-token-refresh.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/claude-token-refresh.log</string>
</dict>
</plist>
EOF
launchctl unload "$LAUNCH_AGENTS/com.claude.token-refresh.plist" 2>/dev/null || true
launchctl load "$LAUNCH_AGENTS/com.claude.token-refresh.plist"
echo "  ✓ Auto token refresh enabled (every 4h)"

# --- Step 6: Check Claude Code login ---
echo ""
if security find-generic-password -s "Claude Code-credentials" -w &>/dev/null; then
    echo "  ✓ Claude Code credentials found"
else
    echo "  ⚠️  Claude Code login required!"
    echo ""
    echo "  Run this to log in:"
    echo ""
    if command -v claude &>/dev/null; then
        echo "    claude"
    else
        echo "    npx @anthropic-ai/claude-code"
    fi
    echo ""
    echo "  Log in with your Claude account, then Ctrl+C to exit."
    echo "  (One-time only — token refreshes automatically after this)"
fi

# --- Step 7: Launch SwiftBar ---
echo ""
echo "  🚀 Launching SwiftBar..."

defaults write com.ameba.SwiftBar PluginDirectory "$PLUGIN_DIR" 2>/dev/null || true
open /Applications/SwiftBar.app

echo ""
echo "  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ✅ Done! Look for 💚 in your menu bar."
echo ""
echo "  Icons:"
echo "    💚 = under 60% (chill)"
echo "    🧡 = 60-89% (watch it)"
echo "    ❤️‍🔥 = 90%+ (danger zone)"
echo ""
echo "  Token auto-refreshes every 4 hours."
echo "  No need to keep Claude Code CLI open."
echo ""
