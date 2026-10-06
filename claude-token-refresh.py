#!/usr/bin/env python3
"""Auto-refresh Claude Code OAuth token by running claude CLI briefly."""
import subprocess
import os
import time
import json


def main():
    # Check if token is still valid
    try:
        result = subprocess.run(
            ["security", "find-generic-password", "-s", "Claude Code-credentials", "-w"],
            capture_output=True, text=True, timeout=5
        )
        if result.returncode == 0 and result.stdout.strip():
            creds = json.loads(result.stdout.strip())
            oauth = creds.get("claudeAiOauth", {})
            exp = oauth.get("expiresAt", 0)
            exp_sec = exp / 1000 if exp > 9999999999 else exp
            remaining = exp_sec - time.time()

            if remaining > 3600:  # More than 1 hour left
                print(f"Token still valid ({remaining/3600:.1f}h remaining), skipping refresh")
                return
    except Exception:
        pass

    # Token expired or expiring soon — run claude to refresh
    print("Token expired or expiring soon, refreshing via claude CLI...")
    claude_path = os.path.expanduser("~/local-npm/node_modules/.bin/claude")

    if not os.path.exists(claude_path):
        print(f"Claude CLI not found at {claude_path}")
        return

    try:
        # Run 'claude --version' — lightweight command that triggers token refresh
        result = subprocess.run(
            [claude_path, "--version"],
            capture_output=True, text=True, timeout=30,
            env={**os.environ, "NO_COLOR": "1"}
        )
        print(f"CLI output: {result.stdout.strip()}")
        print("Token refresh triggered via CLI")
    except Exception as e:
        print(f"CLI refresh failed: {e}")


if __name__ == "__main__":
    main()
