#!/usr/bin/env bash
# Install Debian/Ubuntu packages from Aptfile.core (+ Aptfile.desktop if enabled).
set -euo pipefail

APT_DIR="$(cd "$(dirname "$0")" && pwd)"
APT_DESKTOP="${APT_DESKTOP:-0}"
APT_SETUP_REPOS="${APT_SETUP_REPOS:-${DOTFILES_APT_SETUP_REPOS:-0}}"
APTFILES_ENV="${APTFILES:-}"
APTFILE_LEGACY="${APTFILE:-}"
declare -a APTFILES=()

usage() {
  cat <<'EOF'
Usage: ./apt.sh [--desktop] [--file <path>]

Options:
  --desktop        Include Aptfile.desktop (in addition to Aptfile.core)
  --setup-repos    Configure external repositories (Caddy + Azure CLI + PostgreSQL)
  --file <path>    Include a specific Aptfile (can be repeated)
  -h, --help       Show this help

Environment:
  APT_DESKTOP=1    Include Aptfile.desktop
  APT_SETUP_REPOS=1 Configure external repositories (Caddy + Azure CLI + PostgreSQL)
  APTFILES="..."   Space-separated list of Aptfile paths
  APTFILE="..."    Single Aptfile path (legacy)
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --desktop) APT_DESKTOP=1 ;;
    --setup-repos) APT_SETUP_REPOS=1 ;;
    --file)
      [[ -z "${2:-}" || "$2" == -* ]] && { echo "--file requires a path" >&2; exit 1; }
      APTFILES+=("$2")
      shift
      ;;
    -h|--help) usage; exit 0 ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
  shift
done

if [[ -n "$APTFILES_ENV" ]]; then
  read -r -a APTFILES <<< "$APTFILES_ENV"
fi

if [[ -n "$APTFILE_LEGACY" ]]; then
  APTFILES+=("$APTFILE_LEGACY")
fi

if [[ ${#APTFILES[@]} -eq 0 ]]; then
  if [[ -f "$APT_DIR/Aptfile.core" ]]; then
    APTFILES+=("$APT_DIR/Aptfile.core")
  elif [[ -f "$APT_DIR/Aptfile" ]]; then
    APTFILES+=("$APT_DIR/Aptfile")
  fi
  if [[ "$APT_DESKTOP" == "1" && -f "$APT_DIR/Aptfile.desktop" ]]; then
    APTFILES+=("$APT_DIR/Aptfile.desktop")
  fi
fi

if [[ ${#APTFILES[@]} -eq 0 ]]; then
  echo "No Aptfile found (expected Aptfile.core or Aptfile)." >&2
  exit 1
fi

if ! command -v apt-get >/dev/null 2>&1; then
  echo "apt-get not found; this script is for Debian/Ubuntu." >&2
  exit 1
fi

if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
  SUDO=""
else
  SUDO="sudo"
fi

if [[ "$APT_SETUP_REPOS" == "1" ]]; then
  if [[ -x "$APT_DIR/apt-repos.sh" ]]; then
    "$APT_DIR/apt-repos.sh" --all
  elif [[ -f "$APT_DIR/apt-repos.sh" ]]; then
    bash "$APT_DIR/apt-repos.sh" --all
  else
    echo "Warning: apt-repos.sh not found; skipping repo setup" >&2
  fi
fi

if ! $SUDO apt-get update; then
  echo "Warning: apt-get update failed, continuing anyway..." >&2
fi

for file in "${APTFILES[@]}"; do
  if [[ ! -f "$file" ]]; then
    echo "Warning: Aptfile not found at $file" >&2
    continue
  fi
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%%#*}"
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    [[ -z "$line" ]] && continue

    pkg="$line"
    if dpkg -s "$pkg" >/dev/null 2>&1; then
      echo "Already installed: $pkg"
      continue
    fi

    if ! $SUDO apt-get install -y "$pkg"; then
      echo "Warning: failed to install $pkg" >&2
    fi
  done < "$file"
done
