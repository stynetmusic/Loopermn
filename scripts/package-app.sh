#!/bin/zsh
set -euo pipefail

# ---------------------------------------------------------------------------
# package-app.sh — build (if needed) + package Loopermn as a real .app
#
# Always installs to ~/Applications/Loopermn.app (boot volume).
# WKWebView is unreliable when the host .app lives on an external volume
# (e.g. /Volumes/T9/...). Never open the copy under .build/ for daily use.
#
# Usage:
#   ./scripts/package-app.sh           # release (default)
#   ./scripts/package-app.sh release
#   ./scripts/package-app.sh debug
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

ARCH="$(uname -m)"
PRODUCT_DIR="$ROOT/.build/${ARCH}-apple-macosx/${BUILD_CONFIG}"
BINARY="$PRODUCT_DIR/Loopermn"
INFO_PLIST="$ROOT/Loopermn/Support/Info.plist"
ENTITLEMENTS="$ROOT/Loopermn/Support/Loopermn.entitlements"
APP_ICON_ICNS="$ROOT/Loopermn/Resources/AppIcon/AppIcon.icns"
RESOURCE_BUNDLE="$PRODUCT_DIR/Loopermn_Loopermn.bundle"

INSTALL_DIR="${HOME}/Applications"
APP_DIR="${INSTALL_DIR}/Loopermn.app"
BUILD_APP_DIR="${PRODUCT_DIR}/Loopermn.app"
BUNDLE_ID="com.loopermn.app"

log()  { print -P "%F{cyan}==>%f $1"; }
ok()   { print -P "%F{green}✓%f $1"; }
warn() { print -P "%F{yellow}!%f $1"; }
die()  { print -P "%F{red}error:%f $1" >&2; exit 1; }

[[ -f "$INFO_PLIST" ]] || die "missing Info.plist at $INFO_PLIST"
[[ -f "$ENTITLEMENTS" ]] || die "missing entitlements at $ENTITLEMENTS"

# --- Build -----------------------------------------------------------------

if [[ ! -f "$BINARY" ]]; then
  log "Binary not found — building ($BUILD_CONFIG)…"
fi

log "swift build -c $BUILD_CONFIG"
(
  cd "$ROOT"
  swift build -c "$BUILD_CONFIG"
)

[[ -f "$BINARY" ]] || die "build finished but binary missing: $BINARY"
ok "Binary: $BINARY"
ok "Size:   $(du -h "$BINARY" | awk '{print $1}')"

# --- Package helper --------------------------------------------------------

package_into() {
  local dest="$1"
  log "Packaging → $dest"

  rm -rf "$dest"
  mkdir -p "$dest/Contents/MacOS" "$dest/Contents/Resources"

  cp "$BINARY" "$dest/Contents/MacOS/Loopermn"
  cp "$INFO_PLIST" "$dest/Contents/Info.plist"
  chmod +x "$dest/Contents/MacOS/Loopermn"

  # App icon (Dock / Finder / Launchpad / About)
  if [[ -f "$APP_ICON_ICNS" ]]; then
    cp "$APP_ICON_ICNS" "$dest/Contents/Resources/AppIcon.icns"
    ok "App icon: AppIcon.icns"
  else
    warn "No AppIcon.icns at $APP_ICON_ICNS — Dock will show default icon"
  fi

  if [[ -d "$RESOURCE_BUNDLE" ]]; then
    cp -R "$RESOURCE_BUNDLE" "$dest/Contents/Resources/"
    ok "Copied resource bundle"
  else
    warn "No resource bundle at $RESOURCE_BUNDLE (ok if no assets)"
  fi

  # Drop quarantine so Gatekeeper does not block ad-hoc personal builds
  xattr -cr "$dest" 2>/dev/null || true

  # Ad-hoc sign (personal use). No App Sandbox — required for WKWebView networking.
  codesign --force --sign - \
    --entitlements "$ENTITLEMENTS" \
    --identifier "$BUNDLE_ID" \
    "$dest/Contents/MacOS/Loopermn"

  codesign --force --sign - \
    --entitlements "$ENTITLEMENTS" \
    --identifier "$BUNDLE_ID" \
    "$dest"

  # Verify signature is present
  codesign --verify --verbose=0 "$dest" 2>/dev/null \
    && ok "codesign verify ok" \
    || warn "codesign verify reported issues (often fine for ad-hoc)"
}

# --- Install ---------------------------------------------------------------

mkdir -p "$INSTALL_DIR"

# Keep a build-tree copy for inspection only
package_into "$BUILD_APP_DIR"

# Canonical install for Launchpad / double-click / WKWebView
package_into "$APP_DIR"
xattr -cr "$APP_DIR" 2>/dev/null || true

# Register with Launch Services so Launchpad / Spotlight see it
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
if [[ -x "$LSREGISTER" ]]; then
  "$LSREGISTER" -f "$APP_DIR" 2>/dev/null && ok "Registered with Launch Services" || warn "lsregister failed (app still works via open)"
else
  warn "lsregister not found — open app once for Launchpad to index it"
fi

echo ""
ok "Installed: $APP_DIR"
ok "Config:    $BUILD_CONFIG ($ARCH)"
echo ""
print -P "%F{white}Open with:%f  open \"$APP_DIR\""
print -P "%F{white}Or:%f         double-click in Finder → ~/Applications/Loopermn.app"
print -P "%F{white}Or:%f         Launchpad → Loopermn"
echo ""
print -P "%F{yellow}Note:%f use the ~/Applications copy (local disk), not .build/… on external volumes."
echo ""
