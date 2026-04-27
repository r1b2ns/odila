#!/bin/bash
#
# uninstall-mo.sh
#
# Wraps `mo uninstall` for invocation from a GUI app.
#
# Usage:
#   uninstall-mo.sh [--dry-run] <app_name> [<app_name>...]
#
# When the GUI launches mole there is no controlling terminal, so mole 1.36+
# cannot read /dev/tty for its sudo password prompt — admin-required apps
# (anything in /Applications owned by root) fail with "Admin access denied".
# To avoid that, we detect admin-required targets and re-launch mole through
# `osascript … with administrator privileges`, which surfaces the standard
# macOS auth dialog and runs mole as root so it never has to call sudo.

set -u

# Hardened PATH so `mo` resolves when launched outside a login shell.
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
export MOLE_NO_COLOR=1

DRY_RUN=0
if [[ "${1:-}" == "--dry-run" ]]; then
    DRY_RUN=1
    shift
fi

if [[ $# -eq 0 ]]; then
    echo "Usage: $0 [--dry-run] <app_name> [<app_name>...]" >&2
    exit 2
fi

if ! command -v mo > /dev/null 2>&1; then
    echo "mo (mole CLI) not found on PATH ($PATH)" >&2
    exit 127
fi

MO_BIN="$(command -v mo)"

# Dry-run never modifies anything on disk; no admin required.
if [[ $DRY_RUN -eq 1 ]]; then
    echo y | "$MO_BIN" uninstall "$@" --dry-run
    exit $?
fi

# Decide whether elevation is needed. Any matching .app under /Applications
# that the current user doesn't own will require sudo when mole tries to
# delete it. Items only in ~/Applications/ stay user-mode.
needs_admin=0
for name in "$@"; do
    candidate="/Applications/${name}.app"
    if [[ -d "$candidate" && ! -O "$candidate" ]]; then
        needs_admin=1
        break
    fi
done

if [[ $needs_admin -eq 0 ]]; then
    echo y | "$MO_BIN" uninstall "$@"
    exit $?
fi

# ---------------------------------------------------------------------------
# Elevated path
# ---------------------------------------------------------------------------

# Wrap a value in single quotes for safe inclusion in a /bin/bash command,
# escaping any embedded single quotes.
shell_quote() {
    local s="$1"
    s=${s//\'/\'\\\'\'}
    printf "'%s'" "$s"
}

argv=""
for name in "$@"; do
    argv+=" $(shell_quote "$name")"
done

# The shell snippet that osascript will run as root.
inner="export PATH='$PATH'; export MOLE_NO_COLOR=1; printf 'y\\n' | $(shell_quote "$MO_BIN") uninstall$argv"

# Escape for embedding inside an AppleScript double-quoted string:
# backslashes first, then double quotes.
apple_body=${inner//\\/\\\\}
apple_body=${apple_body//\"/\\\"}

osascript -e "do shell script \"$apple_body\" with administrator privileges"
exit $?
