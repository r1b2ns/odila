#!/usr/bin/env bash
# Fetches the pinned Mole CLI release and assembles a universal (arm64+amd64) binary
# in Vendor/mole/. Validates against the release's SHA256SUMS.
#
# Usage: Scripts/fetch-mole.sh [--force]
# Env overrides: MOLE_VERSION, MOLE_REPO

set -euo pipefail

MOLE_VERSION="${MOLE_VERSION:-V1.35.0}"
MOLE_REPO="${MOLE_REPO:-tw93/Mole}"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENDOR_DIR="$REPO_ROOT/Vendor/mole"
STAMP_FILE="$VENDOR_DIR/.version"

FORCE=0
if [[ "${1:-}" == "--force" ]]; then
    FORCE=1
fi

if [[ "$FORCE" -eq 0 && -f "$STAMP_FILE" && "$(cat "$STAMP_FILE")" == "$MOLE_VERSION" ]]; then
    echo "Mole $MOLE_VERSION already present in $VENDOR_DIR — skipping."
    exit 0
fi

mkdir -p "$VENDOR_DIR"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

BASE_URL="https://github.com/$MOLE_REPO/releases/download/$MOLE_VERSION"

echo "==> Downloading Mole $MOLE_VERSION from $MOLE_REPO"
curl -fL --retry 3 -o "$TMP_DIR/SHA256SUMS" "$BASE_URL/SHA256SUMS"
curl -fL --retry 3 -o "$TMP_DIR/binaries-darwin-arm64.tar.gz" "$BASE_URL/binaries-darwin-arm64.tar.gz"
curl -fL --retry 3 -o "$TMP_DIR/binaries-darwin-amd64.tar.gz" "$BASE_URL/binaries-darwin-amd64.tar.gz"

echo "==> Verifying checksums"
(
    cd "$TMP_DIR"
    grep -E 'binaries-darwin-(arm64|amd64)\.tar\.gz$' SHA256SUMS > verify.txt
    shasum -a 256 -c verify.txt
)

echo "==> Extracting"
mkdir -p "$TMP_DIR/arm64" "$TMP_DIR/amd64"
tar -xzf "$TMP_DIR/binaries-darwin-arm64.tar.gz" -C "$TMP_DIR/arm64"
tar -xzf "$TMP_DIR/binaries-darwin-amd64.tar.gz" -C "$TMP_DIR/amd64"

# The Mole release ships multiple helper binaries (analyze, status, ...).
# Build a universal (fat) binary for each one found in both archives.
echo "==> Building universal binaries"
rm -f "$VENDOR_DIR"/*.bin "$VENDOR_DIR"/analyze "$VENDOR_DIR"/status "$VENDOR_DIR"/mole 2>/dev/null || true

shopt -s nullglob
for arm_bin in "$TMP_DIR/arm64"/*; do
    raw_name="$(basename "$arm_bin")"
    # Strip "-darwin-arm64" / "-arm64" suffix and locate amd64 counterpart.
    stem="${raw_name%-darwin-arm64}"
    stem="${stem%-arm64}"
    amd_bin=""
    for candidate in \
        "$TMP_DIR/amd64/${stem}-darwin-amd64" \
        "$TMP_DIR/amd64/${stem}-amd64" \
        "$TMP_DIR/amd64/${stem}"; do
        if [[ -f "$candidate" ]]; then
            amd_bin="$candidate"
            break
        fi
    done
    if [[ -z "$amd_bin" ]]; then
        echo "  skip $raw_name (missing amd64 counterpart)"
        continue
    fi
    lipo -create "$arm_bin" "$amd_bin" -output "$VENDOR_DIR/$stem"
    chmod +x "$VENDOR_DIR/$stem"
    echo "  built $stem (universal)"
done

# Attempt to fetch upstream LICENSE for bundling compliance.
echo "==> Fetching LICENSE"
curl -fL --retry 3 -o "$VENDOR_DIR/LICENSE" \
    "https://raw.githubusercontent.com/$MOLE_REPO/main/LICENSE" || \
    echo "warning: could not fetch LICENSE; add it manually before release."

echo "$MOLE_VERSION" > "$STAMP_FILE"
echo "==> Mole $MOLE_VERSION ready in $VENDOR_DIR"
ls -la "$VENDOR_DIR"
