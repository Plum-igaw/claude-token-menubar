#!/bin/bash
# Claude Menubar Monitor - One-click installer
# Shows Claude Code usage (session/weekly) in macOS menu bar via SwiftBar
set -e

REPO_URL="https://raw.githubusercontent.com/Plum-igaw/claude-token-menubar/main"
PLUGIN_DIR="$HOME/swiftbar-plugins"

echo ""
echo "  💚 Claude Menubar Monitor - Installer"
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
curl -sL "$REPO_URL/claude-usage-helper.py" -o "$PLUGIN_DIR/claude-usage-helper.py"
chmod +x "$PLUGIN_DIR/claude-usage.5m.sh" "$PLUGIN_DIR/claude-usage-helper.py"
echo "  ✓ Plugin installed"

# --- Step 5: Check Claude Code login ---
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
fi

# --- Step 6: Launch SwiftBar ---
echo ""
echo "  🚀 Launching SwiftBar..."
echo ""

# Set plugin directory preference if first launch
defaults write com.ameba.SwiftBar PluginDirectory "$PLUGIN_DIR" 2>/dev/null || true
open /Applications/SwiftBar.app

echo "  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ✅ Done! Look for 💚 in your menu bar."
echo ""
echo "  Icons:"
echo "    💚 = under 60% (chill)"
echo "    🧡 = 60-89% (watch it)"
echo "    ❤️‍🔥 = 90%+ (danger zone)"
echo ""
