#!/usr/bin/env python3
"""Auto-refresh Claude Code OAuth token before it expires."""
import subprocess
import json
import urllib.request
import urllib.error
import time
import sys


def main():
    # Read credentials from keychain
    try:
        result = subprocess.run(
            ["security", "find-generic-password", "-s", "Claude Code-credentials", "-w"],
            capture_output=True, text=True, timeout=5
        )
        if result.returncode != 0 or not result.stdout.strip():
            print("No credentials found")
            return
        creds = json.loads(result.stdout.strip())
    except Exception as e:
        print(f"Error reading keychain: {e}")
        return

    if "claudeAiOauth" not in creds:
        print("No OAuth data")
        return

    oauth = creds["claudeAiOauth"]
    refresh_token = oauth.get("refreshToken")
    expires_at = oauth.get("expiresAt", 0)

    if not refresh_token:
        print("No refresh token")
        return

    # Check if token still valid (with 5 min buffer)
    now_ms = int(time.time() * 1000)
    if expires_at and now_ms < expires_at - 300000:
        remaining_min = (expires_at - now_ms) / 60000
        print(f"Token still valid ({remaining_min:.0f} min remaining)")
        return

    # Token expired or expiring soon — refresh it
    print("Refreshing token...")
    payload = json.dumps({
        "grant_type": "refresh_token",
        "refresh_token": refresh_token
    }).encode()

    req = urllib.request.Request(
        "https://platform.claude.com/v1/oauth/token",
        data=payload,
        headers={"Content-Type": "application/json"},
        method="POST"
    )

    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            result = json.loads(resp.read().decode())
    except urllib.error.HTTPError as e:
        print(f"Refresh failed: {e.code} {e.reason}")
        return
    except Exception as e:
        print(f"Refresh error: {e}")
        return

    new_access = result.get("access_token")
    if not new_access:
        print("No access_token in response")
        return

    # Update credentials
    oauth["accessToken"] = new_access
    if "refresh_token" in result:
        oauth["refreshToken"] = result["refresh_token"]
    if "expires_at" in result:
        exp = result["expires_at"]
        if exp < 9999999999:
            exp = exp * 1000
        oauth["expiresAt"] = exp

    # Write back to keychain
    new_creds_json = json.dumps(creds)
    subprocess.run(
        ["security", "delete-generic-password", "-s", "Claude Code-credentials"],
        capture_output=True, timeout=5
    )
    subprocess.run(
        ["security", "add-generic-password", "-s", "Claude Code-credentials",
         "-a", "claude-code", "-w", new_creds_json],
        capture_output=True, timeout=5
    )
    print("Token refreshed successfully!")


if __name__ == "__main__":
    main()
