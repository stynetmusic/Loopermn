#!/bin/zsh
set -euo pipefail

# ---------------------------------------------------------------------------
# run.sh — build, install to ~/Applications, then launch
#
# Always opens ~/Applications/Loopermn.app (local disk) so WKWebView works.
#
# Usage:
#   ./scripts/run.sh           # release (default) + launch
#   ./scripts/run.sh release
#   ./scripts/run.sh debug
# ---------------------------------------------------------------------------

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_CONFIG="${1:-release}"
APP="${HOME}/Applications/Loopermn.app"

case "$BUILD_CONFIG" in
  release|debug) ;;
  *)
    echo "error: config must be 'release' or 'debug' (got: $BUILD_CONFIG)" >&2
    exit 1
    ;;
esac

print -P "%F{cyan}==>%f Build + install ($BUILD_CONFIG)…"
"$ROOT/scripts/package-app.sh" "$BUILD_CONFIG"

[[ -d "$APP" ]] || {
  print -P "%F{red}error:%f app missing after package: $APP" >&2
  exit 1
}

# Ensure quarantine is clear right before open
xattr -cr "$APP" 2>/dev/null || true

# Replace any running instance so you always get the fresh binary
if pgrep -x Loopermn >/dev/null 2>&1; then
  print -P "%F{cyan}==>%f Stopping previous Loopermn…"
  pkill -x Loopermn 2>/dev/null || true
  # Wait briefly for clean exit
  for _ in {1..20}; do
    pgrep -x Loopermn >/dev/null 2>&1 || break
    sleep 0.1
  done
  pkill -9 -x Loopermn 2>/dev/null || true
fi

print -P "%F{cyan}==>%f Launching local app…"
open "$APP"

# Confirm process started
sleep 0.4
if pgrep -x Loopermn >/dev/null 2>&1; then
  print -P "%F{green}✓%f Loopermn is running"
else
  print -P "%F{yellow}!%f open returned but process not seen yet — check Dock / Force Quit if needed"
fi

echo ""
print -P "%F{green}✓%f Launched: %F{white}$APP%f"
print -P "   Bundle:  com.loopermn.app"
print -P "   Config:  $BUILD_CONFIG"
echo ""
