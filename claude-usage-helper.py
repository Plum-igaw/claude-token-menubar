#!/usr/bin/env python3
"""Helper for claude-usage SwiftBar plugin. Handles token extraction and API calls."""
import sys
import json
import urllib.request
import urllib.error
import os
import time
from datetime import datetime

CACHE_FILE = os.path.expanduser("~/.claude-usage-cache.json")
CACHE_MAX_AGE = 240  # 4 minutes

def get_token():
    """Get OAuth token from macOS Keychain, auto-refreshing if expired."""
    import subprocess

    try:
        result = subprocess.run(
            ["security", "find-generic-password", "-s", "Claude Code-credentials", "-w"],
            capture_output=True, text=True, timeout=5
        )
        if result.returncode != 0 or not result.stdout.strip():
            cred_file = os.path.expanduser("~/.claude/.credentials.json")
            if os.path.exists(cred_file):
                with open(cred_file) as f:
                    creds = json.load(f)
            else:
                return None
        else:
            creds = json.loads(result.stdout.strip())
    except Exception:
        return None

    if "claudeAiOauth" not in creds:
        if "accessToken" in creds:
            return creds["accessToken"]
        return None

    oauth = creds["claudeAiOauth"]
    access_token = oauth.get("accessToken")
    expires_at = oauth.get("expiresAt", 0)
    refresh_token = oauth.get("refreshToken")

    # Check if token is expired (expiresAt is in milliseconds)
    now_ms = int(time.time() * 1000)
    if expires_at and now_ms > expires_at - 60000:  # expired or expiring within 1 min
        if refresh_token:
            new_token = refresh_access_token(refresh_token, creds)
            if new_token:
                return new_token
        # If refresh failed, try the old token anyway (might still work briefly)
        return access_token

    return access_token


def refresh_access_token(refresh_token, original_creds):
    """Use refresh token to get a new access token, update keychain."""
    import subprocess

    try:
        data = json.dumps({
            "grant_type": "refresh_token",
            "refresh_token": refresh_token
        }).encode()

        req = urllib.request.Request(
            "https://platform.claude.com/v1/oauth/token",
            data=data,
            headers={"Content-Type": "application/json"},
            method="POST"
        )

        with urllib.request.urlopen(req, timeout=10) as resp:
            result = json.loads(resp.read().decode())

        new_access = result.get("access_token")
        new_refresh = result.get("refresh_token", refresh_token)
        new_expires = result.get("expires_at")  # might be seconds or ms

        if not new_access:
            return None

        # Update the credentials in keychain
        oauth = original_creds["claudeAiOauth"]
        oauth["accessToken"] = new_access
        oauth["refreshToken"] = new_refresh
        if new_expires:
            # Normalize to milliseconds
            if new_expires < 9999999999:
                new_expires = new_expires * 1000
            oauth["expiresAt"] = new_expires

        # Write back to keychain
        new_creds_json = json.dumps(original_creds)
        subprocess.run(
            ["security", "delete-generic-password", "-s", "Claude Code-credentials"],
            capture_output=True, timeout=5
        )
        subprocess.run(
            ["security", "add-generic-password", "-s", "Claude Code-credentials",
             "-a", "claude-code", "-w", new_creds_json],
            capture_output=True, timeout=5
        )

        return new_access

    except Exception:
        return None


def fetch_usage(token):
    """Fetch usage from Anthropic API."""
    req = urllib.request.Request(
        "https://api.anthropic.com/api/oauth/usage",
        headers={"Authorization": f"Bearer {token}"}
    )
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            return json.loads(resp.read().decode())
    except urllib.error.HTTPError as e:
        return None
    except Exception:
        return None


def load_cache():
    """Load cache if fresh enough."""
    if not os.path.exists(CACHE_FILE):
        return None
    try:
        age = time.time() - os.path.getmtime(CACHE_FILE)
        with open(CACHE_FILE) as f:
            data = json.load(f)
        # Return with staleness info
        return data, age
    except Exception:
        return None


def save_cache(data):
    """Save data to cache."""
    with open(CACHE_FILE, "w") as f:
        json.dump(data, f)


def iso_to_epoch(iso_str):
    """Convert ISO timestamp to epoch."""
    try:
        dt = datetime.fromisoformat(iso_str)
        return int(dt.timestamp())
    except Exception:
        return 0


def parse_usage(data):
    """Parse API response into session/weekly values."""
    session_pct = 0
    weekly_pct = 0
    session_reset = 0
    weekly_reset = 0

    if "five_hour" in data:
        session_pct = int(round(data["five_hour"].get("utilization", 0) or 0))
        session_reset = iso_to_epoch(data["five_hour"].get("resets_at", ""))

    if "seven_day" in data:
        weekly_pct = int(round(data["seven_day"].get("utilization", 0) or 0))
        weekly_reset = iso_to_epoch(data["seven_day"].get("resets_at", ""))

    # Fallback: limits array
    if session_pct == 0 and "limits" in data:
        for limit in data["limits"]:
            kind = limit.get("kind", "")
            group = limit.get("group", "")
            pct = limit.get("percent", 0)
            reset = iso_to_epoch(limit.get("resets_at", ""))

            if kind == "session" or group == "session":
                session_pct = int(pct) if pct else 0
                session_reset = reset
            elif kind == "weekly_all" or (group == "weekly" and kind != "weekly_scoped"):
                if weekly_pct == 0:
                    weekly_pct = int(pct) if pct else 0
                    weekly_reset = reset

    return session_pct, weekly_pct, session_reset, weekly_reset


def format_reset(epoch):
    """Format reset time as human-readable string."""
    now = int(time.time())
    diff = epoch - now
    if diff <= 0:
        return "now"
    if diff < 3600:
        return f"~{diff // 60}m"
    elif diff < 86400:
        h = diff // 3600
        m = (diff % 3600) // 60
        return f"~{h}h{m}m"
    else:
        d = diff // 86400
        return f"~{d}d"


def main():
    # 1. Get token
    token = get_token()
    if not token:
        print("STATUS:NO_TOKEN")
        return

    # 2. Check cache
    cache_result = load_cache()
    if cache_result:
        data, age = cache_result
        if age < CACHE_MAX_AGE:
            session_pct, weekly_pct, session_reset, weekly_reset = parse_usage(data)
            cache_time = datetime.fromtimestamp(os.path.getmtime(CACHE_FILE)).strftime("%Y-%m-%d %H:%M:%S")
            print(f"STATUS:OK")
            print(f"SESSION:{session_pct}")
            print(f"WEEKLY:{weekly_pct}")
            print(f"SESSION_RESET:{session_reset}")
            print(f"WEEKLY_RESET:{weekly_reset}")
            print(f"LAST_CHECK:{cache_time}")
            return

    # 3. Fetch fresh
    data = fetch_usage(token)
    if data:
        save_cache(data)
        session_pct, weekly_pct, session_reset, weekly_reset = parse_usage(data)
        cache_time = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        print(f"STATUS:OK")
        print(f"SESSION:{session_pct}")
        print(f"WEEKLY:{weekly_pct}")
        print(f"SESSION_RESET:{session_reset}")
        print(f"WEEKLY_RESET:{weekly_reset}")
        print(f"LAST_CHECK:{cache_time}")
        return

    # 4. API failed — try stale cache
    if cache_result:
        data, age = cache_result
        session_pct, weekly_pct, session_reset, weekly_reset = parse_usage(data)
        cache_time = datetime.fromtimestamp(os.path.getmtime(CACHE_FILE)).strftime("%Y-%m-%d %H:%M:%S")
        print(f"STATUS:STALE")
        print(f"SESSION:{session_pct}")
        print(f"WEEKLY:{weekly_pct}")
        print(f"SESSION_RESET:{session_reset}")
        print(f"WEEKLY_RESET:{weekly_reset}")
        print(f"LAST_CHECK:{cache_time}")
        return

    print("STATUS:API_ERROR")


if __name__ == "__main__":
    main()
