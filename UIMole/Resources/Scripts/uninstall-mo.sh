#!/bin/bash
#
# uninstall-mo.sh
#
# Wraps `mo uninstall` for invocation from a GUI app.
#
# Usage:
#   uninstall-mo.sh [--dry-run] <app_name> [<app_name>...]
#
# We deliberately run mole as the regular user, NOT as root via osascript
# admin privileges. mole hangs at "Finalizing list..." when invoked as
# root via `do shell script with administrator privileges` — likely a
# mole bug specific to that environment. As the user, mole detects
# whether sudo is needed per-app: for ~/Applications/ items owned by
# the user it just proceeds; for /Applications/ items owned by root,
# mole pops its own native auth dialog (osascript display dialog) to
# collect the password and uses sudo internally.

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

if [[ $DRY_RUN -eq 1 ]]; then
    echo y | mo uninstall "$@" --dry-run
    exit $?
fi

# Real uninstall: pipe `y\n` to satisfy the [y/N] confirmation. mole
# handles its own sudo prompting via a native auth dialog when needed.
echo y | mo uninstall "$@"
exit $?
