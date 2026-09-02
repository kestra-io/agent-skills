#!/usr/bin/env bash
#
# ensure-kestractl.sh — check for kestractl and, on request, install/upgrade it
# using the official published installer.
#
# Dry-run by default: prints status and, if action is needed, the exact PLAN it
# WOULD run. Nothing is installed until you pass --install.
#
# Usage:
#   ensure-kestractl.sh                       # report status + plan (no changes)
#   ensure-kestractl.sh --install --install-dir ~/.local/bin
#   ensure-kestractl.sh --install --install-dir "$(dirname "$0")/bin"
#
# Env (all optional):
#   KESTRACTL_MIN_VERSION   minimum acceptable version   (default: 1.16.0)
#   KESTRACTL_VERSION       version to install            (default: installer's "latest")
#   KESTRACTL_INSTALL_DIR   install target               (same as --install-dir)
#
# Install-dir choice (required for --install): pick ONE of
#   1. ~/.local/bin                  — user home scope
#   2. <this scripts dir>/bin        — self-contained to the skill
# Never a system path unless you pass one explicitly. No sudo.
#
# The published installer (OS/arch detection, GitHub-release download, sha256
# checksum verification) is:
#   https://raw.githubusercontent.com/kestra-io/kestractl/main/install-scripts/install.sh
set -euo pipefail

MIN_VERSION="${KESTRACTL_MIN_VERSION:-1.16.0}"
WANT_VERSION="${KESTRACTL_VERSION:-}"
INSTALL_DIR="${KESTRACTL_INSTALL_DIR:-}"
INSTALLER_URL="https://raw.githubusercontent.com/kestra-io/kestractl/main/install-scripts/install.sh"
APPLY=0

while [ $# -gt 0 ]; do
  case "$1" in
    --install)      APPLY=1 ;;
    --install-dir)  INSTALL_DIR="${2:-}"; shift ;;
    --install-dir=*) INSTALL_DIR="${1#*=}" ;;
    -h|--help)      sed -n '2,32p' "$0"; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; exit 2 ;;
  esac
  shift
done

say() { printf '%s\n' "$*"; }

# Return 0 if $1 >= $2 (dotted numeric versions).
version_ge() {
  [ "$1" = "$2" ] && return 0
  local lo
  lo="$(printf '%s\n%s\n' "$1" "$2" | sort -t. -k1,1n -k2,2n -k3,3n | head -n1)"
  [ "$lo" = "$2" ]
}

current_version() {
  command -v kestractl >/dev/null 2>&1 || return 1
  # First line looks like: "kestractl v1.15.0"
  kestractl version 2>/dev/null | head -n1 | sed -E 's/^[^0-9]*//; s/[^0-9.].*$//'
}

resolved_report() {
  local v
  v="$(current_version || true)"
  if [ -n "$v" ]; then
    say "Resolved: kestractl $v ($(command -v kestractl))"
  else
    say "Resolved: kestractl NOT on PATH"
  fi
}

path_warning() {
  case ":${PATH}:" in
    *":$1:"*) : ;;
    *) say "NOTE: $1 is not on your PATH — add it:  export PATH=\"$1:\$PATH\"" ;;
  esac
}

CUR="$(current_version || true)"

if [ -n "$CUR" ] && version_ge "$CUR" "$MIN_VERSION"; then
  say "OK: kestractl $CUR is installed and >= minimum $MIN_VERSION."
  resolved_report
  exit 0
fi

if [ -z "$CUR" ]; then
  say "kestractl is not on PATH."
else
  say "kestractl $CUR is older than the minimum ($MIN_VERSION) this skill expects."
fi

# --- action needed ---------------------------------------------------------
plan_dir_hint() {
  say "  Choose an install dir (pass --install-dir):"
  say "    1. \$HOME/.local/bin            (user home scope)"
  say "    2. $(cd "$(dirname "$0")" && pwd)/bin   (self-contained to this skill)"
}

installer_env=""
[ -n "$WANT_VERSION" ] && installer_env="VERSION=$WANT_VERSION "

if [ "$APPLY" -ne 1 ]; then
  say ""
  say "PLAN (dry-run — nothing changed). To apply, re-run with --install --install-dir <dir>:"
  say "  ${installer_env}INSTALL_DIR=<dir> bash -c 'curl -fsSL $INSTALLER_URL | bash'"
  plan_dir_hint
  say ""
  say "After install, set up a connection context (you will be asked which):"
  say "  # OSS (basic auth):"
  say "  kestractl config add default http://localhost:8080 main --username YOUR_USERNAME --password YOUR_PASSWORD --default"
  say "  # Enterprise (API token):"
  say "  kestractl config add default https://kestra.example.com production --token YOUR_TOKEN --default"
  say "  # config file: ~/.kestractl/config.yaml   env: KESTRACTL_HOST/TENANT/TOKEN/USERNAME/PASSWORD"
  exit 0
fi

# --- apply ---------------------------------------------------------------
if [ -z "$INSTALL_DIR" ]; then
  say "ERROR: --install requires --install-dir (or KESTRACTL_INSTALL_DIR)."
  plan_dir_hint
  exit 2
fi
case "$INSTALL_DIR" in
  "~"/*) INSTALL_DIR="$HOME/${INSTALL_DIR#\~/}" ;;
esac
mkdir -p "$INSTALL_DIR"

say "Installing kestractl into $INSTALL_DIR via the official installer ..."
say "  ${installer_env}INSTALL_DIR=$INSTALL_DIR  curl -fsSL $INSTALLER_URL | bash"
if [ -n "$WANT_VERSION" ]; then
  VERSION="$WANT_VERSION" INSTALL_DIR="$INSTALL_DIR" bash -c "curl -fsSL '$INSTALLER_URL' | bash"
else
  INSTALL_DIR="$INSTALL_DIR" bash -c "curl -fsSL '$INSTALLER_URL' | bash"
fi

export PATH="$INSTALL_DIR:$PATH"
hash -r 2>/dev/null || true

NEW="$(current_version || true)"
if [ -z "$NEW" ]; then
  say "ERROR: kestractl still not runnable after install."
  exit 1
fi
if ! version_ge "$NEW" "$MIN_VERSION"; then
  say "WARNING: installed kestractl $NEW is still below the minimum $MIN_VERSION."
fi
resolved_report
path_warning "$INSTALL_DIR"
say ""
say "Next: set up a connection context (ask the user which edition/auth):"
say "  kestractl config add default http://localhost:8080 main --username YOUR_USERNAME --password YOUR_PASSWORD --default   # OSS"
say "  kestractl config add default https://kestra.example.com production --token YOUR_TOKEN --default                       # Enterprise"
