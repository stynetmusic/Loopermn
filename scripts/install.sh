#!/bin/zsh
set -euo pipefail

# ---------------------------------------------------------------------------
# install.sh — build + install Loopermn.app to ~/Applications (no launch)
#
# Usage:
#   ./scripts/install.sh           # release (default)
#   ./scripts/install.sh release
#   ./scripts/install.sh debug
# ---------------------------------------------------------------------------

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_CONFIG="${1:-release}"

case "$BUILD_CONFIG" in
  release|debug) ;;
  *)
    echo "error: config must be 'release' or 'debug' (got: $BUILD_CONFIG)" >&2
    exit 1
    ;;
esac

print -P "%F{cyan}==>%f Installing Loopermn ($BUILD_CONFIG)…"
"$ROOT/scripts/package-app.sh" "$BUILD_CONFIG"

APP="${HOME}/Applications/Loopermn.app"
print -P "%F{green}✓%f Done. App ready at:"
echo "  $APP"
echo ""
print -P "Launch later with:  %F{white}open \"$APP\"%f"
print -P "Or open %F{white}~/Applications/Loopermn.app%f in Finder / Launchpad."
