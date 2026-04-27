#!/usr/bin/env bash
# Verifies that the runtime dependencies UIMole expects are present on the
# host. Installs anything missing.
#
#   - Homebrew (https://brew.sh)
#   - Mole CLI (tw93/Mole) — exposes the `mo` command used by the Uninstall flow
#
# Usage: Scripts/setup.sh [--check]
#   --check  Only report status, never install. Exit code is non-zero if any
#            dependency is missing.

set -euo pipefail

CHECK_ONLY=0
if [[ "${1:-}" == "--check" ]]; then
    CHECK_ONLY=1
fi

# ANSI helpers (skipped when stdout isn't a TTY, e.g. when piped).
if [[ -t 1 ]]; then
    BOLD="\033[1m"
    GREEN="\033[32m"
    YELLOW="\033[33m"
    RED="\033[31m"
    DIM="\033[2m"
    RESET="\033[0m"
else
    BOLD=""; GREEN=""; YELLOW=""; RED=""; DIM=""; RESET=""
fi

ok()    { printf "${GREEN}✓${RESET} %s\n" "$1"; }
warn()  { printf "${YELLOW}!${RESET} %s\n" "$1"; }
fail()  { printf "${RED}✗${RESET} %s\n" "$1" >&2; }
step()  { printf "\n${BOLD}%s${RESET}\n" "$1"; }

# ---------------------------------------------------------------------------
# Homebrew
# ---------------------------------------------------------------------------

ensure_brew_in_path() {
    # Apple Silicon installs to /opt/homebrew, Intel to /usr/local. Either way
    # this shell may not have it on PATH yet (fresh install), so source the env.
    if [[ -x /opt/homebrew/bin/brew ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [[ -x /usr/local/bin/brew ]]; then
        eval "$(/usr/local/bin/brew shellenv)"
    fi
}

check_brew() {
    step "Checking Homebrew"
    ensure_brew_in_path
    if command -v brew >/dev/null 2>&1; then
        ok "brew found at $(command -v brew)"
        return 0
    fi
    warn "Homebrew not found"
    return 1
}

install_brew() {
    step "Installing Homebrew"
    printf "${DIM}Running the official installer — you'll be asked for your password.${RESET}\n"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    ensure_brew_in_path
    if ! command -v brew >/dev/null 2>&1; then
        fail "Homebrew install reported success but brew is still not on PATH."
        exit 1
    fi
    ok "Homebrew installed"
}

# ---------------------------------------------------------------------------
# Mole (tw93/Mole) — the CLI ships as `mo`
# ---------------------------------------------------------------------------

check_mole() {
    step "Checking Mole"
    if command -v mo >/dev/null 2>&1; then
        ok "mo found at $(command -v mo)"
        return 0
    fi
    warn "Mole (mo) not found"
    return 1
}

install_mole() {
    step "Installing Mole"
    if ! command -v brew >/dev/null 2>&1; then
        fail "brew is required to install Mole."
        exit 1
    fi
    brew tap tw93/tap
    brew install mole
    if ! command -v mo >/dev/null 2>&1; then
        fail "Mole install reported success but mo is still not on PATH."
        exit 1
    fi
    ok "Mole installed"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

missing=0

if ! check_brew; then
    if (( CHECK_ONLY )); then
        missing=1
    else
        install_brew
    fi
fi

if ! check_mole; then
    if (( CHECK_ONLY )); then
        missing=1
    else
        install_mole
    fi
fi

step "Summary"
if (( CHECK_ONLY )) && (( missing )); then
    fail "Some dependencies are missing. Re-run without --check to install them."
    exit 1
fi

ok "UIMole dependencies are ready."
